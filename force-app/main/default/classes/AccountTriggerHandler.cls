/**
 * Account trigger handler. Keeps logic out of the trigger and delegates
 * business rules to AccountService so they can be unit tested without DML.
 */
public with sharing class AccountTriggerHandler extends TriggerHandler {
    private List<Account> newRecords;
    private Map<Id, Account> oldMap;

    public AccountTriggerHandler() {
        super();
        this.newRecords = (List<Account>) Trigger.new;
        this.oldMap = (Map<Id, Account>) Trigger.oldMap;
    }

    protected override void beforeInsert() {
        AccountService.normalize(newRecords);
        AccountService.assignTier(newRecords);
    }

    protected override void beforeUpdate() {
        List<Account> changed = AccountService.recordsWithChangedRevenue(newRecords, oldMap);
        AccountService.normalize(newRecords);
        AccountService.assignTier(changed);
    }

    protected override void afterUpdate() {
        AccountService.createFollowUpTasksForTierUpgrades(newRecords, oldMap);
    }
}
