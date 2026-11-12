@IsTest
private class FoodBankMonthlyVisitorsTest {
    private static FoodBankMonthlyVisitors.Request request(Id contactId, Integer year, String visitType) {
        FoodBankMonthlyVisitors.Request r = new FoodBankMonthlyVisitors.Request();
        r.contactId = contactId; r.year = year; r.visitType = visitType;
        return r;
    }
    @IsTest static void emptyAndInvalidRequests() {
        System.assertEquals(0, FoodBankMonthlyVisitors.getMonthlyCounts(null).size());
        System.assertEquals(0, FoodBankMonthlyVisitors.getMonthlyCounts(new List<FoodBankMonthlyVisitors.Request>()).size());
        Contact c = new Contact(LastName='No visits'); insert c;
        FoodBankMonthlyVisitors.Result r = FoodBankMonthlyVisitors.getMonthlyCounts(
            new List<FoodBankMonthlyVisitors.Request>{request(c.Id, Date.today().year(), null)})[0];
        System.assertEquals(0, r.uniqueMonthlyVisits);
        System.assertEquals(0, r.totalYearlyVisits);
        System.assertEquals(0, r.december);
        Boolean thrown = false;
        try { FoodBankMonthlyVisitors.getMonthlyCounts(new List<FoodBankMonthlyVisitors.Request>{request(null, 2026, null)}); }
        catch (FoodBankMonthlyVisitors.MonthlyVisitorsException e) { thrown = true; }
        System.assert(thrown);
        thrown = false;
        try { FoodBankMonthlyVisitors.getMonthlyCounts(new List<FoodBankMonthlyVisitors.Request>{request(c.Id, 1800, null)}); }
        catch (FoodBankMonthlyVisitors.MonthlyVisitorsException e) { thrown = true; }
        System.assert(thrown);
    }
    @IsTest static void countsByTypeMonthAndContact() {
        Integer year = Date.today().year();
        Account household = new Account(Name='Visit test household'); insert household;
        Contact a = new Contact(LastName='Visitor A', AccountId=household.Id);
        Contact b = new Contact(LastName='Visitor B', AccountId=household.Id);
        insert new List<Contact>{a,b};
        List<Food_Bank_Visit__c> visits = new List<Food_Bank_Visit__c>{
            new Food_Bank_Visit__c(Household__c=household.Id, Visitor__c=a.Id, Visit_Type__c='Home Delivery', Visit_Date__c=Datetime.newInstanceGmt(year,2,10,12,0,0)),
            new Food_Bank_Visit__c(Household__c=household.Id, Visitor__c=a.Id, Visit_Type__c='Home Delivery', Visit_Date__c=Datetime.newInstanceGmt(year,2,11,12,0,0)),
            new Food_Bank_Visit__c(Household__c=household.Id, Visitor__c=a.Id, Visit_Type__c='Home Delivery', Visit_Date__c=Datetime.newInstanceGmt(year,3,10,12,0,0)),
            new Food_Bank_Visit__c(Household__c=household.Id, Visitor__c=b.Id, Visit_Type__c='Home Delivery', Visit_Date__c=Datetime.newInstanceGmt(year,4,10,12,0,0))
        };
        insert visits;
        List<FoodBankMonthlyVisitors.Request> reqs = new List<FoodBankMonthlyVisitors.Request>{
            request(a.Id, year, 'Home Delivery'), request(b.Id, year, 'Home Delivery'),
            request(a.Id, year, null), request(a.Id, year-1, 'Home Delivery')
        };
        Test.startTest();
        List<FoodBankMonthlyVisitors.Result> results = FoodBankMonthlyVisitors.getMonthlyCounts(reqs);
        Test.stopTest();
        System.assertEquals(4, results.size());
        System.assertEquals(2, results[0].uniqueMonthlyVisits);
        System.assertEquals(3, results[0].totalYearlyVisits);
        System.assertEquals(1, results[0].february);
        System.assertEquals(1, results[0].march);
        System.assertEquals(0, results[0].january);
        System.assertEquals(1, results[1].uniqueMonthlyVisits);
        System.assertEquals(1, results[1].totalYearlyVisits);
        System.assertEquals(1, results[1].april);
        System.assertEquals(3, results[2].totalYearlyVisits);
        System.assertEquals(0, results[3].totalYearlyVisits);
    }
}
