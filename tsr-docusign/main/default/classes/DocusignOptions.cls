/**
 * DocusignOptions
 * @description Stores all the docusign settings that a required
 *              to make the callout to docusign.
 * @author Thomas Tran, Traction on Demand
 * @date 01-18-2017
 */
public with sharing class DocusignOptions {
	//Initial values found on the Docusign Settings (Custom Settings)
	public String integratorKey {get; set;}
	public String certificateLabel {get; set;}
	public String authenticationService {get; set;}
	public String oAuthLogin {get; set;}
	public String redirectUri {get; set;}
	public String userId {get; set;}
	public String accountId {get; set;}
	public String userInfoEndpoint {get; set;}
	public Integer timeout {get; set;}

	//Populated by callout
	public String baseURL {get; set;}
	public String returnURL {get; set;}
	public String envelopeId {get; set;}
	public String postRecipientViewURL {get; set;}

	public DocusignOptions() {
		Docusign_Settings__c settings = Docusign_Settings__c.getInstance(); 

		this.integratorKey 			= settings.Integrator_Key__c;
		this.certificateLabel 		= settings.Certificate_Label__c;
		this.authenticationService  = settings.Authentication_Service__c;
		this.oAuthLogin 			= settings.OAuth_Login__c;
		this.redirectUri 			= settings.Redirect_Uri__c;
		this.userId 				= settings.User_Id__c;
		this.accountId 				= settings.Account_Id__c;
		this.userInfoEndpoint 		= settings.User_Info_Endpoint__c;
		this.timeout       			= Integer.valueOf(settings.Timeout__c);
	}

	public Boolean validate(){
		return String.isNotBlank(integratorKey) &&
			String.isNotBlank(certificateLabel) &&
			String.isNotBlank(authenticationService) &&
			String.isNotBlank(oAuthLogin) &&
			String.isNotBlank(accountId) &&
			String.isNotBlank(userInfoEndpoint) &&
			String.isNotBlank(userId);
	} 
}