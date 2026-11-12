/** Clears stale current-year Home Delivery Contact totals without touching other visit types. */
public without sharing class FoodBankHomeDeliveryCleanupBatch implements Database.Batchable<SObject> {
    public Database.QueryLocator start(Database.BatchableContext bc) {
        Datetime yearStart = Datetime.newInstanceGmt(Date.today().year(), 1, 1, 0, 0, 0);
        Datetime nextYear = Datetime.newInstanceGmt(Date.today().year() + 1, 1, 1, 0, 0, 0);
        return Database.getQueryLocator([
            SELECT Id, Home_Delivery_Total_Visits_ThisYear__c,
                   Home_Delivery_Unique_Monthly_ThisYear__c
            FROM Contact
            WHERE (Home_Delivery_Total_Visits_ThisYear__c > 0
                OR Home_Delivery_Unique_Monthly_ThisYear__c > 0)
            AND Id NOT IN (
                SELECT Visitor__c FROM Food_Bank_Visit__c
                WHERE Visitor__c != null AND Visit_Type__c = 'Home Delivery'
                  AND Visit_Date__c >= :yearStart AND Visit_Date__c < :nextYear
            )
        ]);
    }
    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<Contact> updates = new List<Contact>();
        for (SObject row : scope) {
            updates.add(new Contact(
                Id = (Id)row.get('Id'),
                Home_Delivery_Total_Visits_ThisYear__c = 0,
                Home_Delivery_Unique_Monthly_ThisYear__c = 0
            ));
        }
        if (!updates.isEmpty()) update updates;
    }
    public void finish(Database.BatchableContext bc) {}

    /** Clean at most maxRows stale Contacts in the current transaction. */
    public static Integer clearNext(Integer maxRows) {
        Integer limitSize = (maxRows == null || maxRows < 1) ? 100 : Math.min(maxRows, 200);
        Datetime yearStart = Datetime.newInstanceGmt(Date.today().year(), 1, 1, 0, 0, 0);
        Datetime nextYear = Datetime.newInstanceGmt(Date.today().year() + 1, 1, 1, 0, 0, 0);
        List<Contact> stale = [
            SELECT Id, Home_Delivery_Total_Visits_ThisYear__c,
                   Home_Delivery_Unique_Monthly_ThisYear__c
            FROM Contact
            WHERE (Home_Delivery_Total_Visits_ThisYear__c > 0
                OR Home_Delivery_Unique_Monthly_ThisYear__c > 0)
            AND Id NOT IN (
                SELECT Visitor__c FROM Food_Bank_Visit__c
                WHERE Visitor__c != null AND Visit_Type__c = 'Home Delivery'
                  AND Visit_Date__c >= :yearStart AND Visit_Date__c < :nextYear
            )
            LIMIT :limitSize
        ];
        for (Contact c : stale) {
            c.Home_Delivery_Total_Visits_ThisYear__c = 0;
            c.Home_Delivery_Unique_Monthly_ThisYear__c = 0;
        }
        if (!stale.isEmpty()) update stale;
        return stale.size();
    }
}
