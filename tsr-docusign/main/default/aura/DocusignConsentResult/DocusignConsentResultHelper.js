({
    getDocusignSetting : function(component, helper) {
        var action = component.get('c.getDocusignConfig');

        action.setParams({});

        action.setCallback(this, function(response) {
            var result = response.getReturnValue();
            if(result.isSuccess){
                component.set('v.docusignSetting', result);
            } else{
                helper.showToast(component, result.errorMessage, 'error');
            }
        });

        $A.enqueueAction(action);
    },
    requestConsent : function(component, helper) {
        const docusignSetting = component.get('v.docusignSetting');
        window.location.href = 'https://' + docusignSetting.authenticationService + '/oauth/auth?response_type=code&client_id=' + docusignSetting.integratorKey + '&redirect_uri=' + docusignSetting.redirectUri + '&scope=signature+impersonation';
    },
    checkOAuth : function(component, helper) {
        return new Promise((resolve, reject) => {
            var action = component.get('c.checkOAuthValid');

            action.setParams({});
    
            action.setCallback(this, function(response) {
                var result = response.getReturnValue();
                if(result.isSuccess){
                    resolve(result);
                }else{
                    reject(result);
                }
            });
                
            $A.enqueueAction(action);   
        });
    },
    showToast : function(component, message, type) {
        component.set('v.toast', {
            message: message,
            type: (type || 'success'),
            className: 'slds-notify slds-notify_toast slds-theme_' + (type || 'success')
        })
    },
    
})