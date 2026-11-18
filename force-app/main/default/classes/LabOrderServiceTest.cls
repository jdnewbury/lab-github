@IsTest
private class LabOrderServiceTest {
    @IsTest
    static void appliesDefaultsToBlankFields() {
        Lab_Order__c order = new Lab_Order__c(Name = 'Defaults');
        LabOrderService.applyDefaults(new List<Lab_Order__c>{ order });
        System.assertEquals('Draft', order.Status__c);
        System.assertEquals(0, order.Discount__c);
    }

    @IsTest
    static void keepsValuesAlreadySet() {
        Lab_Order__c order = new Lab_Order__c(Name = 'Set', Status__c = 'Submitted', Discount__c = 5);
        LabOrderService.applyDefaults(new List<Lab_Order__c>{ order });
        System.assertEquals('Submitted', order.Status__c);
        System.assertEquals(5, order.Discount__c);
    }

    @IsTest
    static void discountsTheAmount() {
        System.assertEquals(90.00, LabOrderService.discountedAmount(new Lab_Order__c(Amount__c = 100, Discount__c = 10)));
        System.assertEquals(100.00, LabOrderService.discountedAmount(new Lab_Order__c(Amount__c = 100)));
        System.assertEquals(0, LabOrderService.discountedAmount(new Lab_Order__c()));
    }
}
