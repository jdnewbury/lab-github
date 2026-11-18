// scripts/delete-class.js deletes this class and its test in the second commit,
// so the delta carries a destructive manifest. Nothing else refers to it.
public with sharing class LabLegacyFormatter {
    public static String formatAmount(Decimal amount) {
        if (amount == null) {
            return '';
        }
        return 'AUD ' + amount.setScale(2).toPlainString();
    }
}
