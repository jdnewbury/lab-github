trigger LabOrderTrigger on Lab_Order__c (before insert, before update) {
    LabOrderService.applyDefaults(Trigger.new);
}
