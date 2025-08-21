public without sharing class DocusignConsentResultCtlr {

	@AuraEnabled
	public static DocusignConfigResult getDocusignConfig(){
		DocusignConfigResult result = new DocusignConfigResult();
		Docusign_Settings__c settings = Docusign_Settings__c.getInstance(); 
		result.integratorKey = settings.Integrator_Key__c;
		result.redirectUri = settings.Redirect_Uri__c;
		result.authenticationService = settings.Authentication_Service__c;
		result.isSuccess = true;
		return result;
	}
	@AuraEnabled
	public static DocusignConfigResult checkOAuthValid(){
		DocusignConfigResult result = new DocusignConfigResult();
		
		try {
			DocusignRequest dsRequest = new DocusignRequest('GET', '', true);
			DocusignOAuth oauth = dsRequest.getOAuth();
			result.isSuccess = oauth.getAccessTokenSetting().validate() && oauth.getAccessTokenSetting().baseUri != null;
		} catch (Exception ex){
			result.isSuccess = false;
			result.errorMessage = ex.getMessage();
		}
		return result;
	}
	
	public class DocusignConfigResult{
	 	@AuraEnabled
	 	public String integratorKey {get; set;}
	 	@AuraEnabled
	 	public String redirectUri {get; set;}
	 	@AuraEnabled
	 	public String authenticationService {get; set;}
	 	@AuraEnabled
	 	public String errorMessage {get; set;}
	 	@AuraEnabled
	 	public Boolean isSuccess {get; set;}
	}

	public class DocusignException extends Exception {}

}