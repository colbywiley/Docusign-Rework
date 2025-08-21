@isTest(seeAllData=false)
private class DocusignAccessTokenTest {
	@isTest
	static void test_validateEmptySetting() {
		DocusignAccessToken docusignAccessToken = new DocusignAccessToken();

		Test.startTest();
		System.assert(!docusignAccessToken.validate(), 'Should be false for the empty setting');
		Test.stopTest();
	}

	@isTest
	static void test_validateValidSetting() {
		DocusignAccessToken docusignAccessToken = new DocusignAccessToken();
		docusignAccessToken.accessToken = 'abcdefg';
		docusignAccessToken.expiryDateTime = Datetime.now().addSeconds(3600);

		Test.startTest();
		System.assert(docusignAccessToken.validate(), 'Should be true for the valid setting');
		Test.stopTest();
	}

	@isTest
	static void test_validateExpriredSetting() {
		DocusignAccessToken docusignAccessToken = new DocusignAccessToken();
		docusignAccessToken.accessToken = 'abcdefg';
		docusignAccessToken.expiryDateTime = Datetime.now().addSeconds(-10);

		Test.startTest();
		System.assert(!docusignAccessToken.validate(), 'Should be false for the expired setting');
		Test.stopTest();
	}

	@isTest
	static void test_doUpsert_success() {
		DocusignAccessToken accessTokenSetting = new DocusignAccessToken();
		accessTokenSetting.accessToken = 'abcdefg';
		accessTokenSetting.expiryDateTime = Datetime.now().addSeconds(3600);

		Test.startTest();
		accessTokenSetting.doUpsert();
		Test.stopTest();

		Docusign_Access_Token__c docusignAccessTokenSetting = Docusign_Access_Token__c.getInstance();
		String accessToken = DocusignTestDataFactory.getAccessToken(docusignAccessTokenSetting);
		System.assertEquals(accessTokenSetting.accessToken, accessToken, 'Should accessToken be correct');
		System.assert(docusignAccessTokenSetting.Expiry_DateTime__c != null, 'Should Expiry_DateTime__c not be null');
	}

	@isTest
	static void test_doUpsert_accessTokenPartsField() {
		DocusignAccessToken accessTokenSetting = new DocusignAccessToken();
		accessTokenSetting.accessToken = 'eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczpcL1wvYXV0aG9yaXphdGlvbi1zZXJ2ZXIuY29tXC8iLCJeyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczpcL1wvYXV0aG9yaXphdGlvbi1zZXJ2ZXIuY29tXC8iLCJeyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczpcL1wvYXV0aG9yaXphdGlvbi1zZXJ2ZXIuY29tXC8iLCJeyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczpcL1wvYXV0aG9yaXphdGlvbi1zZXJ2ZXIuY29tXC8iLCJeyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczpcL1wvYXV0aG9yaXphdGlvbi1zZXJ2ZXIuY29tXC8iLCJeyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczpcL1wvYXV0aG9yaXphdGlvbi1zZXJ2ZXIuY29tXC8iLCJeyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczpcL1wvYXV0aG9yaXphdGlvbi1zZXJ2ZXIuY29tXC8iLCJeyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczpcL1wvYXV0aG9yaXphdGlvbi1zZXJ2ZXIuY29tXC8iLCJeyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczpcL1wvYXV0aG9yaXphdGlvbi1zZXJ2ZXIuY29tXC8iLCJeyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczpcL1wvYXV0aG9yaXphdGlvbi1zZXJ2ZXIuY29tXC8iLCJ';
		accessTokenSetting.expiryDateTime = Datetime.now().addSeconds(3600);

		Test.startTest();
		accessTokenSetting.doUpsert();
		Test.stopTest();

		Docusign_Access_Token__c docusignAccessTokenSetting = Docusign_Access_Token__c.getInstance();
		System.assert(String.isNotBlank(docusignAccessTokenSetting.Access_Token_Part1__c));
		System.assert(String.isNotBlank(docusignAccessTokenSetting.Access_Token_Part2__c));
		System.assert(String.isNotBlank(docusignAccessTokenSetting.Access_Token_Part3__c));
		System.assert(String.isNotBlank(docusignAccessTokenSetting.Access_Token_Part4__c));
		String accessToken = DocusignTestDataFactory.getAccessToken(docusignAccessTokenSetting);
		System.assertEquals(accessTokenSetting.accessToken, accessToken, 'Should accessToken be correct');
		System.assert(docusignAccessTokenSetting.Expiry_DateTime__c != null, 'Should Expiry_DateTime__c not be null');
	}

	@isTest
	static void test_doUpsert_accessTokenExceedLimit() {
		DocusignAccessToken accessTokenSetting = new DocusignAccessToken();
		accessTokenSetting.accessToken = 'eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczpcL1wvYXV0aG9yaXphdGlvbi1zZXJ2ZXIuY29tXC8iLCJeyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczpcL1wvYXV0aG9yaXphdGlvbi1zZXJ2ZXIuY29tXC8iLCJeyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczpcL1wvYXV0aG9yaXphdGlvbi1zZXJ2ZXIuY29tXC8iLCJeyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczpcL1wvYXV0aG9yaXphdGlvbi1zZXJ2ZXIuY29tXC8iLCJeyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczpcL1wvYXV0aG9yaXphdGlvbi1zZXJ2ZXIuY29tXC8iLCJeyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczpcL1wvYXV0aG9yaXphdGlvbi1zZXJ2ZXIuY29tXC8iLCJeyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczpcL1wvYXV0aG9yaXphdGlvbi1zZXJ2ZXIuY29tXC8iLCJeyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczpcL1wvYXV0aG9yaXphdGlvbi1zZXJ2ZXIuY29tXC8iLCJeyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczpcL1wvYXV0aG9yaXphdGlvbi1zZXJ2ZXIuY29tXC8iLCJeyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczpcL1wvYXV0aG9yaXphdGlvbi1zZXJ2ZXIuY29tXC8iLCJ.eyJpc3MiOiJodHRwczpcL1wvYXV0aG9yaXphdGlvbi1zZXJ2ZXIuY29tXC8iLCJ';
		accessTokenSetting.expiryDateTime = Datetime.now().addSeconds(3600);

		Test.startTest();
		accessTokenSetting.doUpsert();
		Test.stopTest();

		Docusign_Access_Token__c docusignAccessTokenSetting = Docusign_Access_Token__c.getInstance();
		System.assert(String.isBlank(docusignAccessTokenSetting.Access_Token_Part1__c));
		System.assert(String.isBlank(docusignAccessTokenSetting.Access_Token_Part2__c));
		System.assert(String.isBlank(docusignAccessTokenSetting.Access_Token_Part3__c));
		System.assert(String.isBlank(docusignAccessTokenSetting.Access_Token_Part4__c));
		System.assert(String.isBlank(docusignAccessTokenSetting.Base_Uri__c));
		System.assert(docusignAccessTokenSetting.Expiry_DateTime__c == null);
		String accessToken = DocusignTestDataFactory.getAccessToken(docusignAccessTokenSetting);
		System.assert(String.isBlank(accessToken), 'Should accessToken be empty');
	}

	@IsTest
	private static void testAccessTokenHierarchySettingIsOrgDefault() {
		DocusignAccessToken accessTokenSetting = new DocusignAccessToken();
		accessTokenSetting.accessToken = 'eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczpcL1wvYXV0aG9yaXphdGlvbi1zZXJ2ZXIuY29tXC8iLCJeyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczpcL1wvYXV0aG9yaXphdGlvbi1zZXJ2ZXIuY29tXC8iLCJeyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczpcL1wvYXV0aG9yaXphdGlvbi1zZXJ2ZXIuY29tXC8iLCJeyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczpcL1wvYXV0aG9yaXphdGlvbi1zZXJ2ZXIuY29tXC8iLCJeyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczpcL1wvYXV0aG9yaXphdGlvbi1zZXJ2ZXIuY29tXC8iLCJeyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczpcL1wvYXV0aG9yaXphdGlvbi1zZXJ2ZXIuY29tXC8iLCJeyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczpcL1wvYXV0aG9yaXphdGlvbi1zZXJ2ZXIuY29tXC8iLCJeyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczpcL1wvYXV0aG9yaXphdGlvbi1zZXJ2ZXIuY29tXC8iLCJeyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczpcL1wvYXV0aG9yaXphdGlvbi1zZXJ2ZXIuY29tXC8iLCJeyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJpc3MiOiJodHRwczpcL1wvYXV0aG9yaXphdGlvbi1zZXJ2ZXIuY29tXC8iLCJ';
		accessTokenSetting.expiryDateTime = Datetime.now().addSeconds(3600);

		Test.startTest();
		accessTokenSetting.doUpsert();
		Test.stopTest();

		Docusign_Access_Token__c orgDefaultToken = Docusign_Access_Token__c.getOrgDefaults();
		Docusign_Access_Token__c currentUserToken = Docusign_Access_Token__c.getInstance(UserInfo.getUserId());

		System.assert(orgDefaultToken.Id != null, 'Setting should be an org default');
		System.assert(currentUserToken.Id == null, 'Setting should not be a User setting');
	}
}