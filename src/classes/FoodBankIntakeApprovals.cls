public with sharing class FoodBankIntakeApprovals {
    public class ApprovalException extends Exception {}
    private static final String OBJECT_NAME = 'WCFB_Intake_Contact_Object_Import__c';
    private static final String FIELDS = 'Id, First_Name__c, Last_Name__c, Preferred_Name__c, Birthdate__c, Gender_Identity__c, Race_Ethnicity__c, Email__c, Phone__c, Address__c, City__c, State__c, Zip_Code__c, Household_Size__c, Is_Primary_Applicant__c, Primary_Contact__c, Submission_Id__c, Intake_Status__c, Submitted_Date__c, Language_Spoken__c, Dietary_Restrictions__c, Active_Duty_Military__c, Veteran__c, Has_Disability__c, Staff_Notes__c';
    public class IntakeGroup {
        public Id id {get;set;}
        public String name {get;set;}
        public Datetime submitted {get;set;}
        public Integer householdSize {get;set;}
        public List<SObject> members {get;set;}
    }
    private static void authorize() {
        if (!Schema.sObjectType.Account.isCreateable() || !Schema.sObjectType.Contact.isCreateable() ||
            !Schema.getGlobalDescribe().get(OBJECT_NAME).getDescribe().isUpdateable()) {
            throw new ApprovalException('You do not have intake approval permissions.');
        }
    }
    @RemoteAction
    public static List<IntakeGroup> pending() {
        authorize();
        List<SObject> records = Database.query('SELECT ' + FIELDS + ' FROM ' + OBJECT_NAME +
            ' WHERE Intake_Status__c = \'Pending\' ORDER BY Submitted_Date__c DESC NULLS LAST LIMIT 2000');
        Map<Id, IntakeGroup> groups = new Map<Id, IntakeGroup>();
        List<Id> orderIds = new List<Id>();
        for (SObject r : records) {
            Id parent = (Id)r.get('Primary_Contact__c');
            if (parent != null || r.get('Is_Primary_Applicant__c') != true) continue;
            IntakeGroup g = new IntakeGroup();
            g.id = (Id)r.get('Id');
            g.name = String.valueOf(r.get('First_Name__c')) + ' ' + String.valueOf(r.get('Last_Name__c'));
            g.submitted = (Datetime)r.get('Submitted_Date__c');
            Decimal sizeValue = (Decimal)r.get('Household_Size__c');
            g.householdSize = sizeValue == null ? 1 : sizeValue.intValue();
            g.members = new List<SObject>{r};
            groups.put(g.id, g);
            orderIds.add(g.id);
        }
        for (SObject r : records) {
            Id parent = (Id)r.get('Primary_Contact__c');
            if (parent != null && groups.containsKey(parent)) groups.get(parent).members.add(r);
        }
        List<IntakeGroup> result = new List<IntakeGroup>();
        for (Id id : orderIds) result.add(groups.get(id));
        return result;
    }
    @RemoteAction
    public static String decide(Id primaryId, String decision) {
        authorize();
        if (primaryId == null || (decision != 'Approved' && decision != 'Rejected')) throw new ApprovalException('Invalid approval request.');
        Savepoint sp = Database.setSavepoint();
        try {
            List<SObject> parents = Database.query('SELECT ' + FIELDS + ' FROM ' + OBJECT_NAME +
                ' WHERE Id = :primaryId FOR UPDATE');
            if (parents.size() != 1 || parents[0].get('Is_Primary_Applicant__c') != true ||
                parents[0].get('Primary_Contact__c') != null || parents[0].get('Intake_Status__c') != 'Pending')
                throw new ApprovalException('This household is no longer pending. Refresh the list.');
            SObject primary = parents[0];
            List<SObject> members = Database.query('SELECT ' + FIELDS + ' FROM ' + OBJECT_NAME +
                ' WHERE Primary_Contact__c = :primaryId FOR UPDATE');
            // Apex List.add(index, value) fails when inserting at index 0 of an empty list.
            List<SObject> household = new List<SObject>{ primary };
            household.addAll(members);
            members = household;
            for (SObject r : members) if (r.get('Intake_Status__c') != 'Pending')
                throw new ApprovalException('A household member is no longer pending.');
            if (decision == 'Rejected') {
                // Rejection only closes the intake request. Do not create an Account or Contacts.
                // Update minimal records to avoid writing unrelated imported fields.
                List<SObject> rejected = new List<SObject>();
                for (SObject r : members) {
                    SObject change = Schema.getGlobalDescribe().get(OBJECT_NAME).newSObject((Id)r.get('Id'));
                    change.put('Intake_Status__c', 'Rejected');
                    change.put('Approved_Date__c', Date.today());
                    change.put('Approved_By__c', UserInfo.getUserId());
                    rejected.add(change);
                }
                update rejected;
                return 'Rejected';
            }
            if (decision == 'Approved') {
                Account hh = new Account(Name = 'REPLACE', BillingStreet = (String)primary.get('Address__c'),
                    BillingCity = (String)primary.get('City__c'), BillingState = (String)primary.get('State__c'),
                    BillingPostalCode = (String)primary.get('Zip_Code__c'));
                insert hh;
                List<Contact> contacts = new List<Contact>();
                for (SObject r : members) {
                    Contact c = new Contact(AccountId = hh.Id, FirstName = (String)r.get('First_Name__c'),
                        LastName = (String)r.get('Last_Name__c'), Birthdate = (Date)r.get('Birthdate__c'),
                        MailingStreet = hh.BillingStreet, MailingCity = hh.BillingCity,
                        MailingState = hh.BillingState, MailingPostalCode = hh.BillingPostalCode);
                    if (r == primary) {
                        c.Email = (String)r.get('Email__c');
                        c.Phone = (String)r.get('Phone__c');
                    }
                    contacts.add(c);
                }
                insert contacts;
                for (Integer i = 0; i < members.size(); i++) members[i].put('Salesforce_Contact__c', contacts[i].Id);
            }
            for (SObject r : members) {
                r.put('Intake_Status__c', decision);
                if (decision == 'Approved') {
                    r.put('Approved_Date__c', Date.today());
                    r.put('Approved_By__c', UserInfo.getUserId());
                }
            }
            update members;
            return decision;
        } catch (Exception e) {
            Database.rollback(sp);
            System.debug(LoggingLevel.ERROR, 'Intake approval failed: ' + e.getTypeName() + ': ' + e.getMessage() + ' | ' + e.getStackTraceString());
            throw new ApprovalException(e.getTypeName() + ': ' + e.getMessage());
        }
    }
}
