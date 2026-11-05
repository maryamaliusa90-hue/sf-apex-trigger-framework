/**
 * Base class for trigger handlers.
 * One trigger per object delegates here; subclasses override only the events they need.
 * Provides: context dispatch, per-handler bypass, and a re-entry guard.
 */
public virtual class TriggerHandler {
    private static Set<String> bypassedHandlers = new Set<String>();
    private static Map<String, Integer> runCounts = new Map<String, Integer>();

    @TestVisible
    private System.TriggerOperation context;
    @TestVisible
    private Boolean isTriggerExecuting;
    private Integer maxLoopCount = 5;

    public TriggerHandler() {
        this.isTriggerExecuting = Trigger.isExecuting;
        this.context = Trigger.operationType;
    }

    public void run() {
        if (!validateRun()) {
            return;
        }
        if (!incrementAndCheckLoopCount()) {
            throw new TriggerHandlerException(
                'Maximum loop count of ' + maxLoopCount + ' reached in ' + getHandlerName()
            );
        }
        switch on context {
            when BEFORE_INSERT {
                beforeInsert();
            }
            when BEFORE_UPDATE {
                beforeUpdate();
            }
            when BEFORE_DELETE {
                beforeDelete();
            }
            when AFTER_INSERT {
                afterInsert();
            }
            when AFTER_UPDATE {
                afterUpdate();
            }
            when AFTER_DELETE {
                afterDelete();
            }
            when AFTER_UNDELETE {
                afterUndelete();
            }
        }
    }

    public void setMaxLoopCount(Integer max) {
        this.maxLoopCount = max;
    }

    public static void bypass(String handlerName) {
        bypassedHandlers.add(handlerName);
    }

    public static void clearBypass(String handlerName) {
        bypassedHandlers.remove(handlerName);
    }

    public static Boolean isBypassed(String handlerName) {
        return bypassedHandlers.contains(handlerName);
    }

    @TestVisible
    private static void resetRunCounts() {
        runCounts.clear();
    }

    @TestVisible
    private Boolean validateRun() {
        if (!isTriggerExecuting || context == null) {
            throw new TriggerHandlerException('Trigger handler called outside of trigger execution');
        }
        return !bypassedHandlers.contains(getHandlerName());
    }

    private Boolean incrementAndCheckLoopCount() {
        String key = getHandlerName() + ':' + String.valueOf(context);
        Integer count = runCounts.containsKey(key) ? runCounts.get(key) + 1 : 1;
        runCounts.put(key, count);
        return count <= maxLoopCount;
    }

    @TestVisible
    private String getHandlerName() {
        return String.valueOf(this).substring(0, String.valueOf(this).indexOf(':'));
    }

    protected virtual void beforeInsert() {
    }
    protected virtual void beforeUpdate() {
    }
    protected virtual void beforeDelete() {
    }
    protected virtual void afterInsert() {
    }
    protected virtual void afterUpdate() {
    }
    protected virtual void afterDelete() {
    }
    protected virtual void afterUndelete() {
    }

    public class TriggerHandlerException extends Exception {
    }
}
