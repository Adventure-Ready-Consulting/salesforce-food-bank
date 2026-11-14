trigger FoodBankOnlineReservationAppointmentTrigger on C501_Appointment__c (before insert, before update) {
    // Apply rules when a slot is created or its date/time changes; preserve values during batch updates.
    List<C501_Appointment__c> changed=new List<C501_Appointment__c>();
    for (C501_Appointment__c a:Trigger.new) {
        C501_Appointment__c old=Trigger.isUpdate ? Trigger.oldMap.get(a.Id) : null;
        if (old==null || a.Date__c!=old.Date__c || a.Time__c!=old.Time__c) changed.add(a);
    }
    if (!changed.isEmpty()) FoodBankOnlineReservationService.apply(changed);
}