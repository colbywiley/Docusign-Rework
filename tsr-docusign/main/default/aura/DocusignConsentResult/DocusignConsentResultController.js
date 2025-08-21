({
	init : function(component, event, helper) {
		helper.getDocusignSetting(component, helper);
	},
	requestConsent : function(component, event, helper) {
		helper.checkOAuth(component, helper).then(result => {
			helper.showToast(component, 'You have already signed the consent', 'success');
		})
		.catch(result => {
			if(result.errorMessage === $A.get("$Label.c.Consent_Required")){
				helper.requestConsent(component, helper);
			}else{
				helper.showToast(component, result.errorMessage, 'error');
			}
		});
	},
	checkOAuth : function(component, event, helper) {
		helper.checkOAuth(component, helper).then(result => {
			helper.showToast(component, 'OAuth authentication works', 'success');
		})
		.catch(result => {
			helper.showToast(component, result.errorMessage, 'error');
		});
	},
	hideToast: function(component, event, helper) {
		component.set('v.toast', null);
	}
})