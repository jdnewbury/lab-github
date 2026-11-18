@IsTest
private class LabLegacyFormatterTest {
    @IsTest
    static void formatsTheAmount() {
        System.assertEquals('AUD 12.50', LabLegacyFormatter.formatAmount(12.5));
        System.assertEquals('', LabLegacyFormatter.formatAmount(null));
    }
}
