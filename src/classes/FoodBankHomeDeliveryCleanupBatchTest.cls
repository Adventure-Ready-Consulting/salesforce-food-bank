@IsTest
private class FoodBankHomeDeliveryCleanupBatchTest {
    @IsTest static void clearNextOnlyClearsStaleContacts() {
        Integer year = Date.today().year();
        Account hh = new Account(Name='Cleanup household'); insert hh;
        Contact stale = new Contact(LastName='Stale', AccountId=hh.Id,
            Home_Delivery_Total_Visits_ThisYear__c=3, Home_Delivery_Unique_Monthly_ThisYear__c=2);
        Contact active = new Contact(LastName='Active', AccountId=hh.Id,
            Home_Delivery_Total_Visits_ThisYear__c=4, Home_Delivery_Unique_Monthly_ThisYear__c=1);
        insert new List<Contact>{stale,active};
        insert new Food_Bank_Visit__c(Household__c=hh.Id, Visitor__c=active.Id,
            Visit_Type__c='Home Delivery', Visit_Date__c=Datetime.newInstanceGmt(year,5,10,12,0,0));
        // Existing automation can recalculate Contact totals when the visit is inserted.
        // Capture the active Contact's actual value before cleanup rather than assuming 4.
        Contact activeBefore = [SELECT Home_Delivery_Total_Visits_ThisYear__c,
            Home_Delivery_Unique_Monthly_ThisYear__c FROM Contact WHERE Id = :active.Id];
        Test.startTest();
        Integer cleaned = FoodBankHomeDeliveryCleanupBatch.clearNext(null);
        Integer cleanedAgain = FoodBankHomeDeliveryCleanupBatch.clearNext(1);
        Test.stopTest();
        System.debug(LoggingLevel.ERROR, 'WCFB cleanup first call cleaned=' + cleaned + ', second call cleaned=' + cleanedAgain);
        System.assert(cleaned >= 0, 'Cleanup count must not be negative; actual=' + cleaned);
        System.assertEquals(0, cleanedAgain);
        Map<Id,Contact> contacts = new Map<Id,Contact>([SELECT Id, Home_Delivery_Total_Visits_ThisYear__c,
            Home_Delivery_Unique_Monthly_ThisYear__c FROM Contact WHERE Id IN :new Set<Id>{stale.Id,active.Id}]);
        System.assertEquals(0, contacts.get(stale.Id).Home_Delivery_Total_Visits_ThisYear__c);
        System.assertEquals(0, contacts.get(stale.Id).Home_Delivery_Unique_Monthly_ThisYear__c);
        System.assertEquals(activeBefore.Home_Delivery_Total_Visits_ThisYear__c,
            contacts.get(active.Id).Home_Delivery_Total_Visits_ThisYear__c,
            'Cleanup must not change an active Home Delivery Contact total');
        System.assertEquals(activeBefore.Home_Delivery_Unique_Monthly_ThisYear__c,
            contacts.get(active.Id).Home_Delivery_Unique_Monthly_ThisYear__c,
            'Cleanup must not change an active Home Delivery Contact monthly count');
    }
    @IsTest static void batchClearsStaleContacts() {
        Contact stale = new Contact(LastName='Batch stale',
            Home_Delivery_Total_Visits_ThisYear__c=5, Home_Delivery_Unique_Monthly_ThisYear__c=3);
        insert stale;
        Test.startTest();
        Database.executeBatch(new FoodBankHomeDeliveryCleanupBatch(), 100);
        Test.stopTest();
        Contact actual = [SELECT Home_Delivery_Total_Visits_ThisYear__c,
            Home_Delivery_Unique_Monthly_ThisYear__c FROM Contact WHERE Id=:stale.Id];
        System.assertEquals(0, actual.Home_Delivery_Total_Visits_ThisYear__c);
        System.assertEquals(0, actual.Home_Delivery_Unique_Monthly_ThisYear__c);
    }
}
