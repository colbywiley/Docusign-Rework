({
    // =========================================================
    // DocuSign flows (unchanged server behavior)
    // =========================================================
    signDocusign : function(component) {
        var recordId = component.get('v.recordId');
        var action = component.get('c.docusignSign');
        action.setParams({ "contractAndFormId" : recordId });

        this.showSpinner(component, true);
        action.setCallback(this, function(response) {
            this.showSpinner(component, false);
            var result = response.getReturnValue();
            if (result && result.isSuccess){
                // Redirect to DocuSign recipient view
                window.location.href = result.result;
            } else {
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

        this.showSpinner(component, true);
        action.setCallback(this, function(response) {
            this.showSpinner(component, false);
            var result = response.getReturnValue();
            if (result && result.isSuccess){
                component.set('v.emailSent', true);
            } else {
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

        this.showSpinner(component, true);
        action.setCallback(this, function(response) {
            this.showSpinner(component, false);
            var result = response.getReturnValue();
            if (result && result.isSuccess){
                component.set('v.emailResent', true);
            } else {
                component.set('v.errorMessage', result ? result.errorMessage : 'Unknown error');
                component.set('v.docusignError', true);
            }
        });
        $A.enqueueAction(action);
    },

    /**
     * DocuSign-only “Download PDF” path remains.
     * On Smartwaiver, the server method is a no-op and returns success with an info message.
     * We still mark the contract signed afterward (consistent with former behavior).
     */
    downloadPDF : function(component, helper){
        var recordId = component.get('v.recordId');
        var action = component.get('c.docusignPDF');
        action.setParams({ "contractAndFormId" : recordId });

        this.showSpinner(component, true);
        action.setCallback(this, function(response) {
            var result = response.getReturnValue();
            if (result && result.isSuccess){
                // For DocuSign: PDFs were attached now.
                // For Smartwaiver: attachment is handled asynchronously by webhook/Flow.
                component.set('v.pdfAttached', true);
                component.set('v.statusMessage', 'Document filing in progress.'); // friendly, provider-agnostic
                helper.signContract(component, helper);
            } else {
                this.showSpinner(component, false);
                component.set('v.errorMessage', result ? result.errorMessage : 'Unknown error');
                component.set('v.docusignError', true);
            }
        });
        $A.enqueueAction(action);
    },

    // =========================================================
    // Smartwaiver finalize (single-shot, no polling)
    // =========================================================
    /**
     * Called once after Smartwaiver redirects back with waiverId (if present).
     * - Persists waiverId onto the Contract if the field is blank.
     * - Does NOT fetch/attach the PDF (webhook/Flow are the source of truth).
     * - Marks the contract as signed.
     */
    finalizeSmartwaiverOnce : function(component, helper){
        var recordId = component.get('v.recordId');
        var waiverId = component.get('v.waiverId'); // set by the redirect page/controller when available

        // If no waiverId was provided, we can still mark signed;
        // webhook/Flow will map the record via autoTag and attach the PDF.
        var action = component.get('c.smartwaiverFinalize');
        action.setParams({
            "contractAndFormId" : recordId,
            "waiverId"          : waiverId
        });

        this.showSpinner(component, true);
        action.setCallback(this, function(response) {
            var result = response.getReturnValue();

            // We don’t retry/poll anymore. Just surface a friendly message and move on.
            if (result && result.isSuccess) {
                component.set('v.statusMessage', 'Waiver complete. Close this screen to complete your transaction.');
            } else {
                // Non-fatal: webhook/Flow will still attach when it completes
                var msg = (result && result.errorMessage) ? result.errorMessage : 'Unable to record waiver id.';
                component.set('v.statusMessage', 'We\'re finishing your filing in the background.');
                component.set('v.errorMessage', msg);
                // Do not set v.docusignError unless you want to block UX; leave it informational.
            }

            // Mark the Contract as signed either way (the business decision you chose for async flow)
            helper.signContract(component, helper);
        });

        $A.enqueueAction(action);
    },

    // =========================================================
    // Common
    // =========================================================
    signContract : function(component, helper){
        var recordId = component.get('v.recordId');
        var action = component.get('c.updateContractToSigned');
        action.setParams({ "contractAndFormId" : recordId });

        action.setCallback(this, function(response) {
            this.showSpinner(component, false);
            var result = response.getReturnValue();
            if (!result || !result.isSuccess){
                component.set('v.errorMessage', result ? result.errorMessage : 'Unknown error');
                component.set('v.docusignError', true);
            }
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
