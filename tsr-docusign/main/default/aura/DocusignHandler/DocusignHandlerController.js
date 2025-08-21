({
	init : function(component, event, helper) {
		var flowType = component.get('v.flowType');
		var recordId = component.get('v.recordId');

		if(flowType == 'Sign'){
			helper.signDocusign(component);
		} else if(flowType == 'Email') {
            helper.emailDocusign(component);
		} else if(flowType == 'Resend'){
			helper.resendDocusign(component);
		} else if(flowType == 'Finish'){
			if(component.get('v.event') === 'signing_complete'){
				helper.downloadPDF(component, helper);
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