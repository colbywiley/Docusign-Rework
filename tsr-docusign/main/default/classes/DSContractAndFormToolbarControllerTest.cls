@isTest(seeAllData=false)
private class DSContractAndFormToolbarControllerTest {
	static{
		insert DocusignTestDataFactory.createDocusignConfig();
		insert DocusignTestDataFactory.createDocusignFieldMapping();
	}

	@isTest static void getAttachment(){
		TREX1__Contract_or_Form_Template__c template = DocusignTestDataFactory.createContractTemplate();
		template.Third_Party_Template_Id__c = 'a64abecb-0b7d-4bb3-a991-78f69355cc97';
		template.TREX1__Contract_Expiry_Policy__c = 'At Date';
		template.TREX1__Contract_Valid_For__c = 'Account';
		template.TREX1__Form_Type__c = 'Docusign Form';
		template.TREX1__Valid_Until_Date__c = Date.today().addDays(30);
		template.TREX1__Valid_for_Month_Length__c = 12;
		insert template;

		TREX1__Required_Contract_and_Form__c reqForm = DocusignTestDataFactory.createRequiredContractForm();
		reqForm.TREX1__Contract_or_Form_Template__c = template.Id;

		insert reqForm;

		TREX1__Contract_And_Form__c form = DocusignTestDataFactory.createContractAndForm();
		form.TREX1__Third_Party_Envelope_Id__c = '714c640a-2005-43b3-b37b-5b0bdc714948';
		form.TREX1__Type__c = 'Docusign Form';
		form.TREX1__Template_ID__c = template.Id;
		form.TREX1__Status__c = 'Complete';
		form.Signed_Contract_Retrieved__c = false;
		insert form;

		Contact newContact = DocusignTestDataFactory.createContact();
		newContact.FirstName = 'Test';
		newContact.LastName = 'Test';
		newContact.Email = 'test@test.test';
		insert newContact;

		Contact resultContact = [SELECT Name, Email FROM Contact WHERE Id = :newContact.Id][0];

		MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
		multimock.setStaticResource('https://demo.docusign.net/restapi/v2/login_information', 'Docusign_Base_Url');
		multimock.setStaticResource('https://account-d.docusign.com/oauth/userinfo', 'User_Info');
		multimock.setStaticResource('https://demo.docusign.net/restapi/v2/accounts/15898051/envelopes', 'Docusign_Create_Envelope');
		multimock.setStaticResource('https://demo.docusign.net/restapi/v2/accounts/15898051/envelopes/714c640a-2005-43b3-b37b-5b0bdc714948/documents/combined', 'Docusign_Envelope_Document');
		multimock.setStaticResource('https://demo.docusign.net/restapi/v2/accounts/15898051/envelopes?envelope_ids=714c640a-2005-43b3-b37b-5b0bdc714948', 'Docusign_Envelope_Change_Status');
		multimock.setStatusCode(200);
		multimock.setHeader('Content-Type', 'application/json');

		Test.setMock(HttpCalloutMock.class, multimock);
		Test.startTest();
		
		DocusignContractAndFormToolbarController.getContract(form.Id);

		Test.stopTest();

		List<Attachment> attachResults = [SELECT ParentId FROM Attachment WHERE ParentId = :form.Id];

		System.assertEquals(1, attachResults.size());
		System.assertEquals(form.Id, attachResults[0].ParentId);

		TREX1__Contract_And_Form__c updatedForm = [SELECT Signed_Contract_Retrieved__c FROM TREX1__Contract_And_Form__c WHERE Id = :form.Id];
		System.assert(updatedForm.Signed_Contract_Retrieved__c);
	}
}