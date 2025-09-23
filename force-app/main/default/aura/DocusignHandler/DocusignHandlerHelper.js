({
    // --------------------------
    // DocuSign flows (unchanged)
    // --------------------------
    signDocusign : function(component) {
        var recordId = component.get('v.recordId');
        var action = component.get('c.docusignSign');
        action.setParams({ "contractAndFormId" : recordId });
        action.setCallback(this, function(response) {
            var result = response.getReturnValue();
            if (result && result.isSuccess){
                window.location.href = result.result;
            } else{
                component.set('v.errorMessage', result ? result.errorMessage : 'Unknown error');
                component.set('v.docusignError', true);
            }
        });
        $A.enqueueAction(action);
    },

    emailDocusign : function(component){
        var recordId = component.get('v.recordId');
        var action = component.get('c.docusignEmail');
        action.setParams({ "contractAndFormId" : recordId });
        action.setCallback(this, function(response) {
            var result = response.getReturnValue();
            if (result && result.isSuccess){
                component.set('v.emailSent', true);
            } else{
                component.set('v.errorMessage', result ? result.errorMessage : 'Unknown error');
                component.set('v.docusignError', true);
            }
        });
        $A.enqueueAction(action);
    },

    resendDocusign: function(component){
        var recordId = component.get('v.recordId');
        var action = component.get('c.docusignResend');
        action.setParams({ "contractAndFormId" : recordId });
        action.setCallback(this, function(response) {
            var result = response.getReturnValue();
            if (result && result.isSuccess){
                component.set('v.emailResent', true);
            } else{
                component.set('v.errorMessage', result ? result.errorMessage : 'Unknown error');
                component.set('v.docusignError', true);
            }
        });
        $A.enqueueAction(action);
    },

    downloadPDF : function(component, helper){
        var recordId = component.get('v.recordId');
        var action = component.get('c.docusignPDF');
        action.setParams({ "contractAndFormId" : recordId });
        action.setCallback(this, function(response) {
            var result = response.getReturnValue();
            if (result && result.isSuccess){
                component.set('v.pdfAttached', true);
                helper.signContract(component, helper);
            } else{
                component.set('v.errorMessage', result ? result.errorMessage : 'Unknown error');
                component.set('v.docusignError', true);
            }
        });
        $A.enqueueAction(action);
    },

    // --------------------------
    // Smartwaiver finalize polling
    // --------------------------
    pollSmartwaiverFinalize : function(component, helper){
        var recordId = component.get('v.recordId');
        var waiverId = component.get('v.waiverId');

        var action = component.get('c.smartwaiverFinalize');
        action.setParams({
            "contractAndFormId" : recordId,
            "waiverId"          : waiverId
        });

        action.setCallback(this, function(response) {
            var result = response.getReturnValue();
            if (!result) {
                helper.handlePollFailure(component, helper, 'Unexpected error from server.');
                return;
            }

            if (result.isSuccess){
                component.set('v.pdfAttached', true);
                component.set('v.statusMessage', 'Waiver finalized.');
                helper.signContract(component, helper);
                return;
            }

            var msg = (result.errorMessage || '').toLowerCase();

            // Retry when Smartwaiver isn’t ready yet or it hiccuped (429/5xx)
            var retryable =
                msg.indexOf('not_ready') >= 0 ||
                msg.indexOf('transient_retry') >= 0 ||
                /waiver not found|internal server error|service unavailable|gateway|timeout|temporar|too many requests|rate limit/i.test(msg);

            var retryCount = component.get('v.retryCount') || 0;
            var maxRetries = component.get('v.maxRetries');
            var infinite   = (maxRetries == null || maxRetries <= 0);

            if (retryable && (infinite || retryCount < maxRetries)) {
                retryCount += 1;
                component.set('v.retryCount', retryCount);
                component.set('v.statusMessage', 'Finalizing waiver… attempt ' + retryCount + '.');

                var baseDelay  = component.get('v.retryDelay') || 2000;   // 2s
                var delay      = Math.min(baseDelay + retryCount * 250, 8000); // linear backoff, capped 8s
                var jitter     = Math.floor(Math.random() * 250);         // jitter to avoid thundering herd

                window.setTimeout($A.getCallback(function () {
                    helper.pollSmartwaiverFinalize(component, helper);
                }), delay + jitter);
            } else {
                helper.handlePollFailure(component, helper, result.errorMessage);
            }
        });

        $A.enqueueAction(action);
    },

    handlePollFailure: function(component, helper, message) {
        component.set('v.errorMessage', message || 'Waiver finalization failed.');
        component.set('v.docusignError', true);
        component.set('v.statusMessage', '');
        helper.showSpinner(component, false);
    },

    // --------------------------
    // Common
    // --------------------------
    signContract : function(component, helper){
        var recordId = component.get('v.recordId');
        var action = component.get('c.updateContractToSigned');
        action.setParams({ "contractAndFormId" : recordId });
        action.setCallback(this, function(response) {
            var result = response.getReturnValue();
            if (!result || !result.isSuccess){
                component.set('v.errorMessage', result ? result.errorMessage : 'Unknown error');
                component.set('v.docusignError', true);
            }
            helper.showSpinner(component, false);
        });
        $A.enqueueAction(action);
    },

    showSpinner: function(component, show) {
        var spinner = component.find('tsr-spinner');
        if (spinner) {
            if (show) {
                $A.util.removeClass(spinner, 'slds-hide');
            } else {
                $A.util.addClass(spinner, 'slds-hide');
            }
        }
    }
})