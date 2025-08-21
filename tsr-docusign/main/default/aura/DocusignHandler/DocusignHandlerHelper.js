({
	signDocusign : function(component) {
		var recordId = component.get('v.recordId');
		var action = component.get('c.docusignSign');

		action.setParams({
			"contractAndFormId" : recordId
		});

		action.setCallback(this, function(response) {
            var result = response.getReturnValue();

            if(result.isSuccess){
            	window.location.href = result.result;
            } else{
                component.set('v.errorMessage', result.errorMessage);
                component.set('v.docusignError', true);
            }
        });

        $A.enqueueAction(action);
	},
	emailDocusign : function(component){
        var recordId = component.get('v.recordId');
        var action = component.get('c.docusignEmail');

        action.setParams({
            "contractAndFormId" : recordId
        });

        action.setCallback(this, function(response) {
            var result = response.getReturnValue();

            if(result.isSuccess){
                component.set('v.emailSent', true);
            } else{
                component.set('v.errorMessage', result.errorMessage);
                component.set('v.docusignError', true);
            }
        });

        $A.enqueueAction(action);
	},
	resendDocusign: function(component){
        var recordId = component.get('v.recordId');
        var action = component.get('c.docusignResend');

        action.setParams({
            "contractAndFormId" : recordId
        });

        action.setCallback(this, function(response) {
            var result = response.getReturnValue();

            if(result.isSuccess){
                component.set('v.emailResent', true);
            } else{
                component.set('v.errorMessage', result.errorMessage);
                component.set('v.docusignError', true);
            }
        });

        $A.enqueueAction(action);
    },
    downloadPDF : function(component, helper){
        var recordId = component.get('v.recordId');
        var action = component.get('c.docusignPDF');

        action.setParams({
            "contractAndFormId" : recordId
        });

        action.setCallback(this, function(response) {
            var result = response.getReturnValue();

            if(result.isSuccess){
                component.set('v.pdfAttached', true);
                helper.signContract(component, helper);
            } else{
                component.set('v.errorMessage', result.errorMessage);
                component.set('v.docusignError', true);
            }
        });

        $A.enqueueAction(action);
    },
    signContract : function(component, helper){
        var recordId = component.get('v.recordId');
        var action = component.get('c.updateContractToSigned');

        action.setParams({
            "contractAndFormId" : recordId
        });

        action.setCallback(this, function(response) {
            var result = response.getReturnValue();

            if(!result.isSuccess){
                component.set('v.errorMessage', result.errorMessage);
                component.set('v.docusignError', true);
            }
            
            helper.showSpinner(component, false);
        });

        $A.enqueueAction(action);
    },
    showSpinner: function(component, show) {
      
        var spinner = component.find('tsr-spinner');
        if (show) {
            $A.util.removeClass(spinner, 'slds-hide');
        }
        else {
            $A.util.addClass(spinner, 'slds-hide');       
        }
    }
})