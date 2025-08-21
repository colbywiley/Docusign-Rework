/**
 * DocusignHandlerCtlrTest
 * @description Test class for DocusignHandlerCtlr
 * @author Thomas Tran, Traction on Demand
 * @date 01-24-2017
 */
@isTest(seeAllData=false)
private class DocusignHandlerCtlrTest {
	static{
		PermissionSet docusignFullAccessPS = [SELECT Id FROM PermissionSet WHERE Name = 'Traction_Rec_Docusign_Full_Access'];
		List<PermissionSetAssignment> assignedPS = [SELECT Id FROM PermissionSetAssignment WHERE AssigneeId = :UserInfo.getUserId() AND PermissionSetId = :docusignFullAccessPS.Id];
		
		if(assignedPS.isEmpty()) {
			insert new PermissionSetAssignment(AssigneeId = UserInfo.getUserId(), PermissionSetId = docusignFullAccessPS.Id);
		}

		System.runAs(new User(Id = UserInfo.getUserId())) {
			insert DocusignTestDataFactory.createOrgDefaultAppConfig();
			insert DocusignTestDataFactory.createDocusignConfig();
			insert DocusignTestDataFactory.createDocusignFieldMapping();
		}
	}

	@isTest static void docusignEmail() {
		System.runAs(new User(Id = UserInfo.getUserId())) {
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

			Contact newContact = DocusignTestDataFactory.createContact();
			newContact.FirstName = 'Test';
			newContact.LastName = 'Test';
			newContact.Email = 'test@test.test';
			insert newContact;

			TREX1__Contract_And_Form__c form = DocusignTestDataFactory.createContractAndForm();
			form.TREX1__Type__c = 'Docusign Form';
			form.TREX1__Template_ID__c = template.Id;
			form.TREX1__Contact__c = newContact.Id;
			insert form;

			MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
			multimock.setStaticResource('https://demo.docusign.net/restapi/v2/login_information', 'Docusign_Base_Url');
			multimock.setStaticResource('https://account-d.docusign.com/oauth/userinfo', 'User_Info');
			multimock.setStaticResource('https://demo.docusign.net/restapi/v2/accounts/15898051/envelopes', 'Docusign_Create_Envelope');
			multimock.setStatusCode(200);
			multimock.setHeader('Content-Type', 'application/json');

			Test.setMock(HttpCalloutMock.class, multimock);

			Test.startTest();

			DocusignHandlerCtlr.DocusignResult result = DocusignHandlerCtlr.docusignEmail(form.Id);

			Test.stopTest();

			List<TREX1__Contract_And_Form__c> contracts = [SELECT TREX1__Third_Party_Envelope_Id__c FROM TREX1__Contract_And_Form__c WHERE Id = :form.Id];
			System.assert(result.isSuccess);
			System.assertEquals('714c640a-2005-43b3-b37b-5b0bdc714948' , contracts[0].TREX1__Third_Party_Envelope_Id__c);
		}
	}

	@isTest static void docusignSign() {
		System.runAs(new User(Id = UserInfo.getUserId())) {
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


			Contact newContact = DocusignTestDataFactory.createContact();
			newContact.FirstName = 'Test';
			newContact.LastName = 'Test';
			newContact.Email = 'test@test.test';
			insert newContact;

			TREX1__Contract_And_Form__c form = DocusignTestDataFactory.createContractAndForm();
			form.TREX1__Type__c = 'Docusign Form';
			form.TREX1__Template_ID__c = template.Id;
			form.TREX1__Contact__c = newContact.Id;
			insert form;


			MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
			multimock.setStaticResource('https://demo.docusign.net/restapi/v2/login_information', 'Docusign_Base_Url');
			multimock.setStaticResource('https://account-d.docusign.com/oauth/userinfo', 'User_Info');
			multimock.setStaticResource('https://demo.docusign.net/restapi/v2/accounts/15898051/envelopes', 'Docusign_Create_Envelope');
			multimock.setStaticResource('https://demo.docusign.net/restapi/v2/accounts/15898051/envelopes/714c640a-2005-43b3-b37b-5b0bdc714948/views/recipient', 'Docusign_Post_Recipient_View');
			multimock.setStatusCode(200);
			multimock.setHeader('Content-Type', 'application/json');

			Test.setMock(HttpCalloutMock.class, multimock);

			Test.startTest();

			DocusignHandlerCtlr.DocusignResult result = DocusignHandlerCtlr.docusignSign(form.Id);

			Test.stopTest();

			List<TREX1__Contract_And_Form__c> contracts = [SELECT TREX1__Third_Party_Envelope_Id__c FROM TREX1__Contract_And_Form__c WHERE Id = :form.Id];
			System.assert(result.isSuccess);
			System.assertEquals('714c640a-2005-43b3-b37b-5b0bdc714948' , contracts[0].TREX1__Third_Party_Envelope_Id__c);
		}
	}

	@isTest static void docusignResendEmail() {
		System.runAs(new User(Id = UserInfo.getUserId())) {
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

			Contact newContact = DocusignTestDataFactory.createContact();
			newContact.FirstName = 'Test';
			newContact.LastName = 'Test';
			newContact.Email = 'test@test.test';
			insert newContact;

			TREX1__Contract_And_Form__c form = DocusignTestDataFactory.createContractAndForm();
			form.TREX1__Type__c = 'Docusign Form';
			form.TREX1__Template_ID__c = template.Id;
			form.TREX1__Contact__c = newContact.Id;
			form.TREX1__Third_Party_Envelope_Id__c = '714c640a-2005-43b3-b37b-5b0bdc714948';
			insert form;

			MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
			multimock.setStaticResource('https://demo.docusign.net/restapi/v2/login_information', 'Docusign_Base_Url');
			multimock.setStaticResource('https://account-d.docusign.com/oauth/userinfo', 'User_Info');
			multimock.setStaticResource('https://demo.docusign.net/restapi/v2/accounts/15898051/envelopes/714c640a-2005-43b3-b37b-5b0bdc714948/recipients?resend_envelope=true', 'Docusign_Resend_Envelope_Test');
			multimock.setStatusCode(200);
			multimock.setHeader('Content-Type', 'application/json');

			Test.setMock(HttpCalloutMock.class, multimock);

			Test.startTest();

			DocusignHandlerCtlr.DocusignResult result = DocusignHandlerCtlr.docusignResend(form.Id);

			Test.stopTest();

			List<TREX1__Contract_And_Form__c> contracts = [SELECT TREX1__Third_Party_Envelope_Id__c FROM TREX1__Contract_And_Form__c WHERE Id = :form.Id];
			System.assert(result.isSuccess);
			System.assertEquals('714c640a-2005-43b3-b37b-5b0bdc714948' , contracts[0].TREX1__Third_Party_Envelope_Id__c);
		}
	}

	@isTest static void docusignPDF() {
		System.runAs(new User(Id = UserInfo.getUserId())) {
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


			Contact newContact = DocusignTestDataFactory.createContact();
			newContact.FirstName = 'Test';
			newContact.LastName = 'Test';
			newContact.Email = 'test@test.test';
			insert newContact;

			TREX1__Contract_And_Form__c form = DocusignTestDataFactory.createContractAndForm();
			form.TREX1__Type__c = 'Docusign Form';
			form.TREX1__Template_ID__c = template.Id;
			form.TREX1__Contact__c = newContact.Id;
			insert form;


			MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
			multimock.setStaticResource('https://demo.docusign.net/restapi/v2/login_information', 'Docusign_Base_Url');
			multimock.setStaticResource('https://account-d.docusign.com/oauth/userinfo', 'User_Info');
			multimock.setStaticResource('https://demo.docusign.net/restapi/v2/accounts/15898051/envelopes', 'Docusign_Create_Envelope');
			multimock.setStaticResource('https://demo.docusign.net/restapi/v2/accounts/15898051/envelopes/714c640a-2005-43b3-b37b-5b0bdc714948/documents/combined', 'Docusign_Envelope_Document');
			multimock.setStatusCode(200);
			multimock.setHeader('Content-Type', 'application/json');

			Test.setMock(HttpCalloutMock.class, multimock);

			Test.startTest();

			DocusignHandlerCtlr.DocusignResult result = DocusignHandlerCtlr.docusignPDF(form.Id);

			Test.stopTest();

			List<Attachment> contracts = [SELECT Id FROM Attachment WHERE ParentId = :form.Id];
			System.assert(result.isSuccess);
			System.assert(contracts[0] != null);
		}
	}

	@isTest static void updateContractToSigned() {
		System.runAs(new User(Id = UserInfo.getUserId())) {
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


			Contact newContact = DocusignTestDataFactory.createContact();
			newContact.FirstName = 'Test';
			newContact.LastName = 'Test';
			newContact.Email = 'test@test.test';
			insert newContact;

			TREX1__Contract_And_Form__c form = DocusignTestDataFactory.createContractAndForm();
			form.TREX1__Type__c = 'Docusign Form';
			form.TREX1__Template_ID__c = template.Id;
			form.TREX1__Contact__c = newContact.Id;
			insert form;

			Test.startTest();

			DocusignHandlerCtlr.DocusignResult result = DocusignHandlerCtlr.updateContractToSigned(form.Id);

			Test.stopTest();

			System.assert(result.isSuccess);
		}
	}

	@isTest static void docusignSendEmailThenSign() {
		System.runAs(new User(Id = UserInfo.getUserId())) {
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

			Contact newContact = DocusignTestDataFactory.createContact();
			newContact.FirstName = 'Test';
			newContact.LastName = 'Test';
			newContact.Email = 'test@test.test';
			insert newContact;

			TREX1__Contract_And_Form__c form = DocusignTestDataFactory.createContractAndForm();
			form.TREX1__Type__c = 'Docusign Form';
			form.TREX1__Template_ID__c = template.Id;
			form.TREX1__Contact__c = newContact.Id;
			insert form;

			MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
			multimock.setStaticResource('https://demo.docusign.net/restapi/v2/login_information', 'Docusign_Base_Url');
			multimock.setStaticResource('https://account-d.docusign.com/oauth/userinfo', 'User_Info');
			multimock.setStaticResource('https://demo.docusign.net/restapi/v2/accounts/15898051/envelopes', 'Docusign_Create_Envelope');
			multimock.setStaticResource('https://demo.docusign.net/restapi/v2/accounts/15898051/envelopes/714c640a-2005-43b3-b37b-5b0bdc714948/views/recipient', 'Docusign_Post_Recipient_View');
			multimock.setStatusCode(200);
			multimock.setHeader('Content-Type', 'application/json');

			Test.setMock(HttpCalloutMock.class, multimock);

			Test.startTest();

			DocusignHandlerCtlr.DocusignResult resultEmail = DocusignHandlerCtlr.docusignEmail(form.Id);

			Test.stopTest();

			DocusignHandlerCtlr.DocusignResult resultSign = DocusignHandlerCtlr.docusignSign(form.Id);

			List<TREX1__Contract_And_Form__c> contracts = [SELECT TREX1__Third_Party_Envelope_Id__c FROM TREX1__Contract_And_Form__c WHERE Id = :form.Id];
			System.assert(resultEmail.isSuccess);
			System.assert(resultSign.isSuccess);
			System.assertEquals('714c640a-2005-43b3-b37b-5b0bdc714948' , contracts[0].TREX1__Third_Party_Envelope_Id__c);
		}
	}
	@isTest 
	static void docusignEmailExistingEnvelope() {
		System.runAs(new User(Id = UserInfo.getUserId())) {
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

			Contact newContact = DocusignTestDataFactory.createContact();
			newContact.FirstName = 'Test';
			newContact.LastName = 'Test';
			newContact.Email = 'test@test.test';
			insert newContact;

			TREX1__Contract_And_Form__c form = DocusignTestDataFactory.createContractAndForm();
			form.TREX1__Type__c = 'Docusign Form';
			form.TREX1__Template_ID__c = template.Id;
			form.TREX1__Contact__c = newContact.Id;
			form.TREX1__Capture_Status__c = 'Via Email';
			form.TREX1__Third_Party_Envelope_Id__c = '714c640a-2005-43b3-b37b-5b0bdc714948';
			insert form;

			MultiStaticResourceCalloutMock multimock = new MultiStaticResourceCalloutMock();
			multimock.setStaticResource('https://demo.docusign.net/restapi/v2/login_information', 'Docusign_Base_Url');
			multimock.setStaticResource('https://account-d.docusign.com/oauth/userinfo', 'User_Info');
			multimock.setStaticResource('https://demo.docusign.net/restapi/v2/accounts/15898051/envelopes/714c640a-2005-43b3-b37b-5b0bdc714948/recipients?resend_envelope=true', 'Docusign_Resend_Envelope_Test');
			multimock.setStatusCode(200);
			multimock.setHeader('Content-Type', 'application/json');

			Test.setMock(HttpCalloutMock.class, multimock);

			Test.startTest();

			DocusignHandlerCtlr.DocusignResult result = DocusignHandlerCtlr.docusignEmail(form.Id);

			Test.stopTest();

			List<TREX1__Contract_And_Form__c> contracts = [SELECT TREX1__Third_Party_Envelope_Id__c FROM TREX1__Contract_And_Form__c WHERE Id = :form.Id];
			System.assert(result.isSuccess);
			System.assertEquals('714c640a-2005-43b3-b37b-5b0bdc714948' , contracts[0].TREX1__Third_Party_Envelope_Id__c);
		}
	}
}