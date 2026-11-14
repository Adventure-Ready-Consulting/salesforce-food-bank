public without sharing class FoodBankOnlineReservationService {
    public static Integer weekday(Date d) {
        return Math.mod(Date.newInstance(2024, 1, 1).daysBetween(d), 7) + 1;
    }
    public static String keyFor(Date d, String t) {
        return String.valueOf(weekday(d)) + '|' + (t == null ? '' : t.trim());
    }
    public static Map<String,Integer> rules() {
        Map<String,Integer> result = new Map<String,Integer>();
        for (FoodBank_Online_Reservation_Rule__c r : [SELECT Rule_Key__c, Reserved__c FROM FoodBank_Online_Reservation_Rule__c]) {
            result.put(r.Rule_Key__c, r.Reserved__c == null ? 0 : Integer.valueOf(r.Reserved__c));
        }
        return result;
    }
    public static void apply(List<C501_Appointment__c> appointments) {
        Map<String,Integer> values = rules();
        for (C501_Appointment__c a : appointments) {
            if (a.Date__c == null) continue;
            Integer v = values.get(keyFor(a.Date__c,a.Time__c));
            a.Online_Reserved_Capacity__c = v == null ? 0 : v;
        }
    }
    public class GridCell {
        public Integer weekday;
        public String slotTime;
        public Integer reserved;
        public GridCell(Integer d, String t, Integer r) { weekday=d;slotTime=t;reserved=r; }
    }
    @RemoteAction
    public static List<GridCell> loadGrid() {
        Date today = Date.today();
        Date monday = today.addDays(8-weekday(today)); // next complete Monday-Sunday
        Date untilDate = monday.addDays(7);
        Map<String,Integer> values = rules();
        Map<String,GridCell> cells = new Map<String,GridCell>();
        for (C501_Appointment__c a : [SELECT Date__c,Time__c FROM C501_Appointment__c
             WHERE Date__c >= :monday AND Date__c < :untilDate ORDER BY Date__c,Available_Time__c]) {
            if (a.Date__c == null || String.isBlank(a.Time__c)) continue;
            String k=keyFor(a.Date__c,a.Time__c);
            if (!cells.containsKey(k)) cells.put(k,new GridCell(weekday(a.Date__c),a.Time__c,values.containsKey(k)?values.get(k):0));
        }
        List<GridCell> result=cells.values();
        return result;
    }
    @RemoteAction
    public static String saveGrid(String jsonValues) {
        if (String.isBlank(jsonValues)) throw new AuraHandledException('Missing reservation values');
        List<Object> entries=(List<Object>)JSON.deserializeUntyped(jsonValues);
        if (entries.size()>500) throw new AuraHandledException('Too many reservation cells');
        // Only allow weekday/time combinations represented by the upcoming full schedule week.
        Set<String> allowed=new Set<String>();
        for (GridCell cell:loadGrid()) allowed.add(String.valueOf(cell.weekday)+'|'+cell.slotTime);
        Map<String,FoodBank_Online_Reservation_Rule__c> changes=new Map<String,FoodBank_Online_Reservation_Rule__c>();
        for (Object raw:entries) {
            Map<String,Object> e=(Map<String,Object>)raw;
            Integer d=Integer.valueOf(String.valueOf(e.get('weekday')));
            String t=(String)e.get('time');
            Integer n=Integer.valueOf(String.valueOf(e.get('reserved')));
            String k=String.valueOf(d)+'|'+t;
            if (!allowed.contains(k) || n<0 || n>999) throw new AuraHandledException('Invalid reservation cell: '+k);
            changes.put(k,new FoodBank_Online_Reservation_Rule__c(Name=k,Rule_Key__c=k,Weekday__c=d,Slot_Time__c=t,Reserved__c=n));
        }
        if (!changes.isEmpty()) upsert changes.values() FoodBank_Online_Reservation_Rule__c.Rule_Key__c;
        Database.executeBatch(new FoodBankOnlineReservationBatch(),200);
        return 'Saved '+changes.size()+' reservation rules. Future appointment updates have been queued.';
    }
}
