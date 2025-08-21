@isTest(seeAllData=false)
private class DocusignOAuthTest {
	@isTest 
	static void DocusignOAuth_obtainAccessToken() {
		setupMock();
		insert DocusignTestDataFactory.createDocusignConfig();
		insert DocusignTestDataFactory.createDocusignFieldMapping();
		DocusignAccessToken docusignAccessTokenInvalid = new DocusignAccessToken();

		Test.startTest();
		DocusignOAuth docusignOAuth = new DocusignOAuth();
		docusignOAuth.obtainAccessToken();
		Test.stopTest();
		DocusignAccessToken docusignAccessTokenValid = docusignOAuth.accessTokenSetting;
		System.assertEquals(false, docusignAccessTokenInvalid.validate(), 'Access token is invalid because it does not exist');
		System.assert(docusignAccessTokenValid.validate(), 'Access token is obtained, so it is valid');
	}
	@isTest 
	static void DocusignOAuth_getAccessTokenFromSetting() {
		// does not mock callout, so if access token is not from setting, it will make a callout which will result in an exception
		insert DocusignTestDataFactory.createDocusignConfig();
		insert DocusignTestDataFactory.createAccessTokenSetting();

		Test.startTest();
		DocusignOAuth docusignOAuth = new DocusignOAuth();
		Test.stopTest();
		System.assert(docusignOAuth.accessTokenSetting.validate(), 'Access token is obtained from setting and it is valid');
	}


	
	@isTest 
	static void DocusignOAuth_docusignSettingInvalid() {
		setupMock();
		Boolean exceptionThrown = false;
		String exceptionError;
		
		Test.startTest();
		try {
			DocusignOAuth docusignOAuth = new DocusignOAuth();
		} catch (Exception e) {
			exceptionThrown = true;
			exceptionError = e.getMessage();
		}
		Test.stopTest();

		System.assert(exceptionThrown, 'Should throw an exception if docusign setting is invalid');
		System.assertEquals(DocusignOAuth.DOCUSIGN_SETTING_ERROR, exceptionError, 'Should error message correct');
	}
	
	@isTest 
	static void DocusignOAuth_accessTokenShouldBeUpdated() {
		setupMock();
		insert DocusignTestDataFactory.createDocusignConfig();
		insert DocusignTestDataFactory.createDocusignFieldMapping();
		Docusign_Access_Token__c docusignAccessTokenSettingEmpty = Docusign_Access_Token__c.getInstance();

		Test.startTest();
		DocusignOAuth docusignOAuth = new DocusignOAuth();
		docusignOAuth.obtainAccessToken();
		docusignOAuth.upsertAccessTokenSetting();
		Test.stopTest();

		Docusign_Access_Token__c docusignAccessTokenSettingUpdated = Docusign_Access_Token__c.getInstance(); 
		String accessTokenEmpty = DocusignTestDataFactory.getAccessToken(docusignAccessTokenSettingEmpty);
		String accessTokenUpdated = DocusignTestDataFactory.getAccessToken(docusignAccessTokenSettingUpdated);
		System.assert(String.isBlank(accessTokenEmpty), 'Access Token should be empty');
		System.assertEquals(null, docusignAccessTokenSettingEmpty.Expiry_DateTime__c, 'Expiry_DateTime__c should be null');
		System.assert(String.isNotBlank(accessTokenUpdated), 'Access Token should not be empty');
		System.assertNotEquals(null, docusignAccessTokenSettingUpdated.Expiry_DateTime__c, 'Expiry_DateTime__c should not be null');
	}
	@isTest 
	static void DocusignOAuth_getBaseUri_success() {
		setupMock();
		insert DocusignTestDataFactory.createDocusignConfig();
		
		Test.startTest();
		DocusignOAuth docusignOAuth = new DocusignOAuth();
		docusignOAuth.obtainAccessToken();
		String baseUri = docusignOAuth.getBaseUri();
		Test.stopTest();

		System.assertEquals('https://demo.docusign.net/restapi/v2/accounts/15898051', baseUri, 'Should error message correct');
	}
	@isTest 
	static void DocusignOAuth_getBaseUri_withoutSetting() {
		setupMock();
		Boolean exceptionThrown = false;
		String exceptionError;
		
		Test.startTest();
		try {
			DocusignOAuth docusignOAuth = new DocusignOAuth();
			docusignOAuth.obtainAccessToken();
			docusignOAuth.getBaseUri();
		} catch (Exception e) {
			exceptionThrown = true;
			exceptionError = e.getMessage();
		}
		Test.stopTest();

		System.assert(exceptionThrown, 'Should throw an exception if docusign setting is invalid');
		System.assertEquals(DocusignOAuth.DOCUSIGN_SETTING_ERROR, exceptionError, 'Should error message correct');
	}
	@isTest 
	static void DocusignOAuth_getBaseUri_withoutAccessToken() {
		setupMock();
		insert DocusignTestDataFactory.createDocusignConfig();

		Boolean exceptionThrown = false;
		String exceptionError;
		
		Test.startTest();
		try {
			DocusignOAuth docusignOAuth = new DocusignOAuth();
			docusignOAuth.accessTokenSetting.accessToken = '';
			docusignOAuth.accessTokenSetting.baseUri = '';
			docusignOAuth.getBaseUri();
		} catch (Exception e) {
			exceptionThrown = true;
			exceptionError = e.getMessage();
		}
		Test.stopTest();

		System.assert(exceptionThrown, 'Should throw an exception if access token has not been obtained');
		System.assertEquals(DocusignOAuth.MISSING_ACCESS_TOKEN, exceptionError, 'Should error message correct');
	}
	@isTest 
	static void DocusignOAuth_getBaseUri_cannotGetBaseUri() {
		setupMock();
		Docusign_Settings__c setting = DocusignTestDataFactory.createDocusignConfig();
		setting.Account_Id__c = '1111111';
		insert setting;
		

		Boolean exceptionThrown = false;
		String exceptionError;
		
		Test.startTest();
		try {
			DocusignOAuth docusignOAuth = new DocusignOAuth();
			docusignOAuth.obtainAccessToken();
			docusignOAuth.getBaseUri();
		} catch (Exception e) {
			exceptionThrown = true;
			exceptionError = e.getMessage();
		}
		Test.stopTest();

		System.assert(exceptionThrown, 'Should throw an exception if no base URI return');
		System.assertEquals(DocusignOAuth.CANNOT_GET_BASE_URI, exceptionError, 'Should error message correct');
	}
	@isTest 
	static void DocusignOAuth_getBaseUri_JSONException() {
		MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
		multimock.setStaticResource('https://account-d.docusign.com/oauth/userinfo', 'User_Info_Invalid');
		multimock.setStatusCode(200);
		multimock.setHeader('Content-Type', 'application/json');

		Test.setMock(HttpCalloutMock.class, multimock);
		Docusign_Settings__c setting = DocusignTestDataFactory.createDocusignConfig();
		insert setting;

		Boolean exceptionThrown = false;
		String exceptionError;
		
		Test.startTest();
		try {
			DocusignOAuth docusignOAuth = new DocusignOAuth();
			docusignOAuth.obtainAccessToken();
			docusignOAuth.getBaseUri();
		} catch (Exception e) {
			exceptionThrown = true;
			exceptionError = e.getMessage();
		}
		Test.stopTest();

		System.assert(exceptionThrown, 'Should throw an exception if return JSON is invalid');
		System.assertEquals(DocusignOAuth.DESERIALIZE_JSON_ERROR, exceptionError, 'Should error message correct');
	}

	static void setupMock(){
		MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
		multimock.setStaticResource('https://account-d.docusign.com/oauth/userinfo', 'User_Info');
		multimock.setStatusCode(200);
		multimock.setHeader('Content-Type', 'application/json');

		Test.setMock(HttpCalloutMock.class, multimock);
	}
}