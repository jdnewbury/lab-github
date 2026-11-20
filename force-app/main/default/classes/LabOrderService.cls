public with sharing class LabOrderService {
    public static final String STATUS_DRAFT = 'Draft';
    public static final String STATUS_APPROVED = 'Approved';

    public static void applyDefaults(List<Lab_Order__c> orders) {
        for (Lab_Order__c order : orders) {
            if (String.isBlank(order.Status__c)) {
                order.Status__c = STATUS_DRAFT;
            }
            if (order.Discount__c == null) {
                order.Discount__c = 0;
            }
        }
    }

    public static Decimal discountedAmount(Lab_Order__c order) {
        if (order.Amount__c == null) {
            return 0;
        }
        Decimal discount = order.Discount__c == null ? 0 : order.Discount__c;
        return (order.Amount__c * (100 - discount) / 100).setScale(2);
    }
}
