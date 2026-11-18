@IsTest
private class LabOrderTriggerTest {
    @IsTest
    static void insertSetsDefaults() {
        Lab_Order__c order = new Lab_Order__c(Name = 'Insert', Amount__c = 50);
        insert order;
        order = [SELECT Status__c, Discount__c, Approved_Date__c FROM Lab_Order__c WHERE Id = :order.Id];
        System.assertEquals('Draft', order.Status__c);
        System.assertEquals(0, order.Discount__c);
        System.assertEquals(null, order.Approved_Date__c);
    }

    @IsTest
    static void approvingStampsTheDate() {
        Lab_Order__c order = new Lab_Order__c(Name = 'Approve', Amount__c = 50);
        insert order;
        order.Status__c = 'Approved';
        update order;
        order = [SELECT Approved_Date__c FROM Lab_Order__c WHERE Id = :order.Id];
        System.assertEquals(Date.today(), order.Approved_Date__c, 'the record-triggered flow sets the date');
    }
}
