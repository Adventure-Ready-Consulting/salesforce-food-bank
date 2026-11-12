/** Counts months with visits and total visits for each requested Contact and UTC calendar year. */
public with sharing class FoodBankMonthlyVisitors {
    public class Request {
        @InvocableVariable(label='Contact ID' required=true)
        public Id contactId;
        @InvocableVariable(label='Reporting Year' required=true)
        public Integer year;
        @InvocableVariable(label='Visit Type (blank for all)')
        public String visitType;
    }
    public class Result {
        @InvocableVariable(label='Contact ID') public Id contactId;
        @InvocableVariable(label='Reporting Year') public Integer year;
        @InvocableVariable(label='Unique Monthly Visits') public Integer uniqueMonthlyVisits;
        @InvocableVariable(label='Total Yearly Visits') public Integer totalYearlyVisits;
        @InvocableVariable public Integer january;
        @InvocableVariable public Integer february;
        @InvocableVariable public Integer march;
        @InvocableVariable public Integer april;
        @InvocableVariable public Integer may;
        @InvocableVariable public Integer june;
        @InvocableVariable public Integer july;
        @InvocableVariable public Integer august;
        @InvocableVariable public Integer september;
        @InvocableVariable public Integer october;
        @InvocableVariable public Integer november;
        @InvocableVariable public Integer december;
    }
    public class MonthlyVisitorsException extends Exception {}

    @InvocableMethod(label='Get Contact Food Bank Visit Counts'
        description='For each Contact and year, returns distinct months with visits and total visit records. UTC calendar boundaries; optional Visit Type filter.')
    public static List<Result> getMonthlyCounts(List<Request> requests) {
        List<Result> results = new List<Result>();
        if (requests == null || requests.isEmpty()) return results;
        // Group requests by year and visit type, then query all Contact IDs together.
        Map<String, List<Integer>> indexesByKey = new Map<String, List<Integer>>();
        for (Integer i = 0; i < requests.size(); i++) {
            Request req = requests[i];
            if (req == null || req.contactId == null || req.year == null || req.year < 1900 || req.year > 9998) {
                throw new MonthlyVisitorsException('Each request needs a Contact ID and year between 1900 and 9998.');
            }
            Result r = new Result();
            r.contactId = req.contactId;
            r.year = req.year;
            r.uniqueMonthlyVisits = 0;
            r.totalYearlyVisits = 0;
            r.january = 0; r.february = 0; r.march = 0; r.april = 0;
            r.may = 0; r.june = 0; r.july = 0; r.august = 0;
            r.september = 0; r.october = 0; r.november = 0; r.december = 0;
            results.add(r);
            String visitType = String.isBlank(req.visitType) ? '' : req.visitType.trim();
            String key = String.valueOf(req.year) + '|' + visitType;
            if (!indexesByKey.containsKey(key)) indexesByKey.put(key, new List<Integer>());
            indexesByKey.get(key).add(i);
        }
        for (String key : indexesByKey.keySet()) {
            List<Integer> indexes = indexesByKey.get(key);
            Integer year = requests[indexes[0]].year;
            String visitType = String.isBlank(requests[indexes[0]].visitType) ? null : requests[indexes[0]].visitType.trim();
            Set<Id> contactIds = new Set<Id>();
            for (Integer i : indexes) contactIds.add(requests[i].contactId);
            Datetime startDate = Datetime.newInstanceGmt(year, 1, 1, 0, 0, 0);
            Datetime endDate = Datetime.newInstanceGmt(year + 1, 1, 1, 0, 0, 0);
            List<AggregateResult> rows;
            if (visitType == null) {
                rows = [SELECT Visitor__c visitorId, CALENDAR_MONTH(Visit_Date__c) monthNumber,
                               COUNT(Id) visitCount
                        FROM Food_Bank_Visit__c
                        WHERE Visitor__c IN :contactIds AND Visit_Date__c >= :startDate
                              AND Visit_Date__c < :endDate
                        GROUP BY Visitor__c, CALENDAR_MONTH(Visit_Date__c)];
            } else {
                rows = [SELECT Visitor__c visitorId, CALENDAR_MONTH(Visit_Date__c) monthNumber,
                               COUNT(Id) visitCount
                        FROM Food_Bank_Visit__c
                        WHERE Visitor__c IN :contactIds AND Visit_Type__c = :visitType
                              AND Visit_Date__c >= :startDate AND Visit_Date__c < :endDate
                        GROUP BY Visitor__c, CALENDAR_MONTH(Visit_Date__c)];
            }
            Map<Id, Map<Integer, Integer>> countsByContact = new Map<Id, Map<Integer, Integer>>();
            for (AggregateResult ar : rows) {
                Id visitorId = (Id) ar.get('visitorId');
                if (!countsByContact.containsKey(visitorId)) countsByContact.put(visitorId, new Map<Integer, Integer>());
                countsByContact.get(visitorId).put((Integer) ar.get('monthNumber'), (Integer) ar.get('visitCount'));
            }
            for (Integer i : indexes) {
                Result r = results[i];
                Map<Integer, Integer> months = countsByContact.get(r.contactId);
                if (months == null) continue;
                r.uniqueMonthlyVisits = months.size();
                for (Integer m : months.keySet()) r.totalYearlyVisits += months.get(m);
                r.january = months.containsKey(1) ? 1 : 0;
                r.february = months.containsKey(2) ? 1 : 0;
                r.march = months.containsKey(3) ? 1 : 0;
                r.april = months.containsKey(4) ? 1 : 0;
                r.may = months.containsKey(5) ? 1 : 0;
                r.june = months.containsKey(6) ? 1 : 0;
                r.july = months.containsKey(7) ? 1 : 0;
                r.august = months.containsKey(8) ? 1 : 0;
                r.september = months.containsKey(9) ? 1 : 0;
                r.october = months.containsKey(10) ? 1 : 0;
                r.november = months.containsKey(11) ? 1 : 0;
                r.december = months.containsKey(12) ? 1 : 0;
            }
        }
        // Opportunistic, bounded cleanup only for current-year Home Delivery requests.
        // A full sweep is available via FoodBankHomeDeliveryCleanupBatch.
        Boolean runCleanup = false;
        for (Request req : requests) {
            if (req.year == Date.today().year() && req.visitType != null &&
                req.visitType.trim().equalsIgnoreCase('Home Delivery')) {
                runCleanup = true;
                break;
            }
        }
        if (runCleanup) FoodBankHomeDeliveryCleanupBatch.clearNext(100);
        return results;
    }
}
