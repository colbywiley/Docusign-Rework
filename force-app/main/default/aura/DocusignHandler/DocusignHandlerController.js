({
    init : function(component, event, helper) {
        // Parse URL params safely and set attributes once
        try {
            var url = new URL(window.location.href);
            var sp  = url.searchParams;

            if (!component.get('v.initExecuted')) {
                component.set('v.recordId',       component.get('v.recordId')       || sp.get('recordId') || sp.get('id'));
                component.set('v.parentRecordId', component.get('v.parentRecordId') || sp.get('parentId'));
                component.set('v.flowType',       component.get('v.flowType')       || sp.get('flowType'));
                component.set('v.event',          component.get('v.event')          || sp.get('event'));
                component.set('v.waiverId',       component.get('v.waiverId')       || sp.get('waiverid') || sp.get('waiverId'));
                component.set('v.initExecuted', true);
            }
        } catch(e) {
            // ignore parse failures
        }

        var flowType = component.get('v.flowType');

        if (flowType === 'Sign') {
            helper.signDocusign(component);
        } else if (flowType === 'Email') {
            helper.emailDocusign(component);
        } else if (flowType === 'Resend') {
            helper.resendDocusign(component);
        } else if (flowType === 'Finish') {
            if (component.get('v.event') === 'signing_complete') {
                // Smartwaiver path: poll finalize until success or hard error
                helper.showSpinner(component, true);
                component.set('v.statusMessage', 'Finalizing waiver…');
                component.set('v.retryCount', 0);
                helper.pollSmartwaiverFinalize(component, helper);
            }
        }
    },

    showSpinner: function(component, event, helper) {
        helper.showSpinner(component, true);
    },

    hideSpinner: function(component, event, helper) {
        helper.showSpinner(component, false);
    }
})