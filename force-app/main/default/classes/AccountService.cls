/**
 * Bulk-safe Account business rules. Every method accepts a list and performs
 * at most one SOQL query and one DML statement regardless of batch size.
 */
public with sharing class AccountService {
    public static final Decimal ENTERPRISE_THRESHOLD = 50000000;
    public static final Decimal MID_MARKET_THRESHOLD = 5000000;

    public static void normalize(List<Account> accounts) {
        for (Account acc : accounts) {
            if (acc.Name != null) {
                acc.Name = acc.Name.normalizeSpace();
            }
            if (acc.Website != null) {
                acc.Website = acc.Website.trim().toLowerCase().removeStart('http://').removeStart('https://');
            }
        }
    }

    public static void assignTier(List<Account> accounts) {
        for (Account acc : accounts) {
            acc.Rating = tierFor(acc.AnnualRevenue);
        }
    }

    @TestVisible
    private static String tierFor(Decimal revenue) {
        if (revenue == null) {
            return null;
        }
        if (revenue >= ENTERPRISE_THRESHOLD) {
            return 'Hot';
        }
        if (revenue >= MID_MARKET_THRESHOLD) {
            return 'Warm';
        }
        return 'Cold';
    }

    public static List<Account> recordsWithChangedRevenue(List<Account> newRecords, Map<Id, Account> oldMap) {
        List<Account> changed = new List<Account>();
        for (Account acc : newRecords) {
            if (acc.AnnualRevenue != oldMap.get(acc.Id).AnnualRevenue) {
                changed.add(acc);
            }
        }
        return changed;
    }

    public static void createFollowUpTasksForTierUpgrades(List<Account> newRecords, Map<Id, Account> oldMap) {
        List<Task> tasks = new List<Task>();
        for (Account acc : newRecords) {
            Account previous = oldMap.get(acc.Id);
            if (acc.Rating == 'Hot' && previous.Rating != 'Hot') {
                tasks.add(
                    new Task(
                        WhatId = acc.Id,
                        OwnerId = acc.OwnerId,
                        Subject = 'Review enterprise tier upgrade',
                        ActivityDate = Date.today().addDays(3),
                        Priority = 'High'
                    )
                );
            }
        }
        if (!tasks.isEmpty()) {
            insert as user tasks;
        }
    }
}
