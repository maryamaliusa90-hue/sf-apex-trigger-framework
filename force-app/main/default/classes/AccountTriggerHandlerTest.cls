@IsTest
private class AccountTriggerHandlerTest {
    @IsTest
    static void insertNormalizesAndAssignsTierInBulk() {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 200; i++) {
            accounts.add(
                new Account(
                    Name = '  Synthetic   Co ' + i + ' ',
                    Website = 'HTTPS://Example' + i + '.TEST',
                    AnnualRevenue = Math.mod(i, 2) == 0 ? 60000000 : 1000
                )
            );
        }

        Test.startTest();
        insert accounts;
        Test.stopTest();

        Integer hot = 0;
        for (Account acc : [SELECT Name, Website, Rating FROM Account]) {
            Assert.isFalse(acc.Name.contains('  '), 'Name should be whitespace-normalized');
            Assert.isTrue(acc.Website.startsWith('example'), 'Website should be lower-case without scheme');
            if (acc.Rating == 'Hot') {
                hot++;
            }
        }
        Assert.areEqual(100, hot, 'Half of the accounts should be Hot');
    }

    @IsTest
    static void tierUpgradeCreatesOneFollowUpTaskPerAccount() {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 50; i++) {
            accounts.add(new Account(Name = 'Upgrade ' + i, AnnualRevenue = 1000));
        }
        insert accounts;
        for (Account acc : accounts) {
            acc.AnnualRevenue = 75000000;
        }

        Test.startTest();
        update accounts;
        Test.stopTest();

        Assert.areEqual(50, [SELECT COUNT() FROM Task WHERE Subject = 'Review enterprise tier upgrade']);
    }

    @IsTest
    static void unchangedRevenueDoesNotRecalculateTier() {
        Account acc = new Account(Name = 'Stable', AnnualRevenue = 1000);
        insert acc;
        acc.Rating = 'Warm';
        acc.Description = 'manual override';

        update acc;

        Assert.areEqual('Warm', [SELECT Rating FROM Account WHERE Id = :acc.Id].Rating);
    }

    @IsTest
    static void bypassSkipsHandlerLogic() {
        TriggerHandler.bypass('AccountTriggerHandler');
        insert new Account(Name = 'Bypassed', Website = 'HTTPS://Bypassed.TEST', AnnualRevenue = 60000000);
        TriggerHandler.clearBypass('AccountTriggerHandler');

        Account acc = [SELECT Website, Rating FROM Account LIMIT 1];
        Assert.areEqual('HTTPS://Bypassed.TEST', acc.Website, 'Website should not be normalized');
        Assert.isNull(acc.Rating, 'Tier should not be assigned');
    }

    @IsTest
    static void tierBoundaries() {
        Assert.isNull(AccountService.tierFor(null));
        Assert.areEqual('Cold', AccountService.tierFor(4999999));
        Assert.areEqual('Warm', AccountService.tierFor(5000000));
        Assert.areEqual('Hot', AccountService.tierFor(50000000));
    }

    @IsTest
    static void handlerOutsideTriggerThrows() {
        try {
            new AccountTriggerHandler().run();
            Assert.fail('Expected TriggerHandlerException');
        } catch (TriggerHandler.TriggerHandlerException e) {
            Assert.isTrue(e.getMessage().contains('outside of trigger'));
        }
    }
}
