/**
 * Get and store access token and related information
 */
public with sharing class DocusignAccessToken {
	public String accessToken {get; set;}
	public String baseUri {get; set;}
	public Datetime expiryDateTime {get; set;}
	Docusign_Access_Token__c docusignAccessTokenSetting;

	public DocusignAccessToken() {
		docusignAccessTokenSetting = Docusign_Access_Token__c.getOrgDefaults();

		this.accessToken = getAccessToken();
		this.baseUri = docusignAccessTokenSetting.Base_Uri__c;
		this.expiryDateTime = docusignAccessTokenSetting.Expiry_DateTime__c;
	}

	public Boolean validate(){
		return accessToken != null &&
				expiryDateTime != null &&
				expiryDateTime > DateTime.now();
	}
	/**
	 * upsert custom setting should be done manually
	 * if do this automatically every time the access token is updated
	 * could cause exception:
	 * `System.CalloutException: You have uncommitted work pending. Please commit or rollback before calling out`
	 * So this is supposed to be called when all callouts are done, check `DocusignHandlerCtlr.cls`
	 */
	public void doUpsert(){
		Docusign_Access_Token__c docusignAccessTokenSetting = Docusign_Access_Token__c.getOrgDefaults();
		// if access token length is more than limit of access token fields length then don't store it and set fields empty
		if(accessToken.length() > 1020){
			// reset the setting, force it to obtain new one next time
			setAccessTokenEmpty();
		}else{
			docusignAccessTokenSetting.Base_Uri__c = baseUri;
			docusignAccessTokenSetting.Expiry_DateTime__c = expiryDateTime;
			setAccessToken(docusignAccessTokenSetting);
		}
		upsert docusignAccessTokenSetting;
		docusignAccessTokenSetting = Docusign_Access_Token__c.getOrgDefaults();
	}

	public void setAccessTokenEmpty(){
		docusignAccessTokenSetting.Access_Token_Part1__c = null;
		docusignAccessTokenSetting.Access_Token_Part2__c = null;
		docusignAccessTokenSetting.Access_Token_Part3__c = null;
		docusignAccessTokenSetting.Access_Token_Part4__c = null;
		docusignAccessTokenSetting.Base_Uri__c = null;
		docusignAccessTokenSetting.Expiry_DateTime__c = null;
	}
	public String getAccessToken(){
		String accessToken = docusignAccessTokenSetting.Access_Token_Part1__c;
		if(String.isNotBlank(docusignAccessTokenSetting.Access_Token_Part2__c)){
			accessToken += docusignAccessTokenSetting.Access_Token_Part2__c;
		}
		if(String.isNotBlank(docusignAccessTokenSetting.Access_Token_Part3__c)){
			accessToken += docusignAccessTokenSetting.Access_Token_Part3__c;
		}
		if(String.isNotBlank(docusignAccessTokenSetting.Access_Token_Part4__c)){
			accessToken += docusignAccessTokenSetting.Access_Token_Part4__c;
		}
		return accessToken;
	}

	public void setAccessToken(Docusign_Access_Token__c docusignAccessTokenSetting){
		Integer tokenLength = accessToken.length();
		Integer remainingLength = tokenLength;
		docusignAccessTokenSetting.Access_Token_Part1__c = null;
		docusignAccessTokenSetting.Access_Token_Part2__c = null;
		docusignAccessTokenSetting.Access_Token_Part3__c = null;
		docusignAccessTokenSetting.Access_Token_Part4__c = null;

		while (remainingLength > 0) {
			Integer i = Integer.valueOf(remainingLength / 255);
			Integer endPos = Math.min((i + 1) * 255, tokenLength);
			String part = accessToken.substring(i * 255,  endPos);
			docusignAccessTokenSetting.put('Access_Token_Part' + String.valueOf(i + 1) + '__c', part);
			remainingLength -= part.length();
		}
	}
}