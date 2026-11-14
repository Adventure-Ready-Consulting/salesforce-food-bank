public without sharing class FoodBankOnlineReservationBatch implements Database.Batchable<SObject> {
    public Database.QueryLocator start(Database.BatchableContext context) {
        Date today = Date.today();
        return Database.getQueryLocator([SELECT Id,Date__c,Time__c,Online_Reserved_Capacity__c FROM C501_Appointment__c WHERE Date__c >= :today]);
    }
    public void execute(Database.BatchableContext context,List<SObject> scope) {
        List<C501_Appointment__c> appointments=new List<C501_Appointment__c>();
        for (SObject row:scope) appointments.add((C501_Appointment__c)row);
        FoodBankOnlineReservationService.apply(appointments);
        update appointments;
    }
    public void finish(Database.BatchableContext context) {}
}