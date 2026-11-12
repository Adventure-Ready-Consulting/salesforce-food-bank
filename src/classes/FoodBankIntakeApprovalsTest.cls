@IsTest(SeeAllData=false)
private class FoodBankIntakeApprovalsTest {
    private static SObject intake(String first, String last, Boolean primary, Id parentId, String status) {
        SObject r = Schema.getGlobalDescribe().get('WCFB_Intake_Contact_Object_Import__c').newSObject();
        r.put('First_Name__c', first);
        r.put('Last_Name__c', last);
        r.put('Is_Primary_Applicant__c', primary);
        r.put('Intake_Status__c', status);
        r.put('Submission_Id__c', 'TEST-' + first + '-' + last);
        if (parentId != null) r.put('Primary_Contact__c', parentId);
        if (primary) r.put('Household_Size__c', 2);
        return r;
    }

    private static Id makeHousehold() {
        SObject parent = intake('Sample', 'Family', true, null, 'Pending');
        parent.put('Address__c', '123 Test St');
        parent.put('City__c', 'Seattle');
        parent.put('State__c', 'WA');
        parent.put('Zip_Code__c', '98101');
        insert parent;
        insert intake('Second', 'Family', false, (Id)parent.get('Id'), 'Pending');
        return (Id)parent.get('Id');
    }

    @IsTest static void invalidDecisionIsRejected() {
        try {
            FoodBankIntakeApprovals.decide(null, 'Approved');
            System.assert(false, 'Expected validation error');
        } catch (FoodBankIntakeApprovals.ApprovalException e) {
            System.assert(e.getMessage().contains('Invalid approval request'));
        }
    }

    @IsTest static void pendingGroupsPrimaryAndMembers() {
        Id parentId = makeHousehold();
        Test.startTest();
        List<FoodBankIntakeApprovals.IntakeGroup> groups = FoodBankIntakeApprovals.pending();
        Test.stopTest();
        System.assertEquals(1, groups.size(), 'One household, not two individual records');
        System.assertEquals(parentId, groups[0].id);
        System.assertEquals(2, groups[0].members.size());
        System.assertEquals(2, groups[0].householdSize);
        System.assert(groups[0].name.contains('Sample'));
    }

    @IsTest static void rejectSinglePersonHousehold() {
        SObject parent = intake('Single', 'Person', true, null, 'Pending');
        parent.put('Household_Size__c', 1);
        insert parent;
        Id parentId = (Id)parent.get('Id');
        Test.startTest();
        String outcome = FoodBankIntakeApprovals.decide(parentId, 'Rejected');
        Test.stopTest();
        System.assertEquals('Rejected', outcome);
        List<SObject> rows = Database.query('SELECT Intake_Status__c, Approved_Date__c, Approved_By__c FROM WCFB_Intake_Contact_Object_Import__c WHERE Id = :parentId');
        System.assertEquals(1, rows.size());
        System.assertEquals('Rejected', rows[0].get('Intake_Status__c'));
        System.assertEquals(Date.today(), rows[0].get('Approved_Date__c'));
        System.assertEquals(UserInfo.getUserId(), rows[0].get('Approved_By__c'));
        System.assertEquals(0, FoodBankIntakeApprovals.pending().size());
    }

    @IsTest static void rejectUpdatesWholeHousehold() {
        Id parentId = makeHousehold();
        Test.startTest();
        String outcome;
        try { outcome = FoodBankIntakeApprovals.decide(parentId, 'Rejected'); }
        catch (Exception e) { System.assert(false, 'REJECT DIAGNOSTIC: ' + e.getTypeName() + ': ' + e.getMessage()); }
        Test.stopTest();
        System.assertEquals('Rejected', outcome);
        List<SObject> rows = Database.query('SELECT Intake_Status__c FROM WCFB_Intake_Contact_Object_Import__c WHERE Id = :parentId OR Primary_Contact__c = :parentId');
        System.assertEquals(2, rows.size());
        for (SObject r : rows) System.assertEquals('Rejected', r.get('Intake_Status__c'));
        System.assertEquals(0, FoodBankIntakeApprovals.pending().size());
    }

    @IsTest static void approveCreatesAccountContactsAndAudit() {
        Id parentId = makeHousehold();
        Test.startTest();
        String outcome;
        try { outcome = FoodBankIntakeApprovals.decide(parentId, 'Approved'); }
        catch (Exception e) { System.assert(false, 'APPROVE DIAGNOSTIC: ' + e.getTypeName() + ': ' + e.getMessage()); }
        Test.stopTest();
        System.assertEquals('Approved', outcome);
        List<SObject> rows = Database.query('SELECT Intake_Status__c, Approved_Date__c, Approved_By__c, Salesforce_Contact__c FROM WCFB_Intake_Contact_Object_Import__c WHERE Id = :parentId OR Primary_Contact__c = :parentId');
        System.assertEquals(2, rows.size());
        Set<Id> contactIds = new Set<Id>();
        for (SObject r : rows) {
            System.assertEquals('Approved', r.get('Intake_Status__c'));
            System.assertEquals(Date.today(), r.get('Approved_Date__c'));
            System.assertEquals(UserInfo.getUserId(), r.get('Approved_By__c'));
            System.assertNotEquals(null, r.get('Salesforce_Contact__c'));
            contactIds.add((Id)r.get('Salesforce_Contact__c'));
        }
        List<Contact> contacts = [SELECT Id, AccountId FROM Contact WHERE Id IN :contactIds];
        System.assertEquals(2, contacts.size());
        System.assertNotEquals(null, contacts[0].AccountId);
        System.assertEquals(contacts[0].AccountId, contacts[1].AccountId);
        Account household = [SELECT RecordType.DeveloperName, Source__c FROM Account WHERE Id = :contacts[0].AccountId];
        System.assertEquals('HH_Account', household.RecordType.DeveloperName);
        System.assertEquals('Intake Web App', household.Source__c);
        System.assertEquals(0, FoodBankIntakeApprovals.pending().size());
    }

    @IsTest static void cannotProcessHouseholdTwice() {
        Id parentId = makeHousehold();
        try { FoodBankIntakeApprovals.decide(parentId, 'Rejected'); }
        catch (Exception e) { System.assert(false, 'REJECT FIRST DIAGNOSTIC: ' + e.getTypeName() + ': ' + e.getMessage()); }
        Test.startTest();
        try {
            FoodBankIntakeApprovals.decide(parentId, 'Approved');
            System.assert(false, 'Expected stale approval rejection');
        } catch (FoodBankIntakeApprovals.ApprovalException e) {
            System.assert(e.getMessage().contains('no longer pending'), 'UNEXPECTED ERROR: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest static void cannotApproveWhenMemberNotPending() {
        Id parentId = makeHousehold();
        List<SObject> children = Database.query('SELECT Id, Intake_Status__c FROM WCFB_Intake_Contact_Object_Import__c WHERE Primary_Contact__c = :parentId');
        children[0].put('Intake_Status__c', 'Rejected');
        update children;
        Test.startTest();
        try {
            FoodBankIntakeApprovals.decide(parentId, 'Approved');
            System.assert(false, 'Expected member status rejection');
        } catch (FoodBankIntakeApprovals.ApprovalException e) {
            System.assert(e.getMessage().contains('no longer pending'), 'UNEXPECTED ERROR: ' + e.getMessage());
        }
        Test.stopTest();
    }
}
