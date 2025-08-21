/**
 * Docusign
 * @description Method calls to docusign,
 * @author Thomas Tran, Traction on Demand
 * @date 01-18-2017
 */
public with sharing class Docusign {
	private final Set<String> CONTACT_AND_FORM_FIELD_API = new Set<String>{
		'Id', 'TREX1__Contact__c', 'TREX1__Contact__r.Name', 'TREX1__Contact__r.Email', 'TREX1__Template_Id__c'
	};

	private final Set<String> CONTACT_AND_FORM_TEMPLATE_FIELD_API = new Set<String>{
		'Id', 'Third_Party_Template_Id__c'
	};
	
	private final String GET_TEXT                         = 'GET';
	private final String POST_TEXT                        = 'POST';
	private final String PUT_TEXT                         = 'PUT';
	private final String X_DOCUSIGN_AUTHENTICATION        = 'X-DocuSign-Authentication';
	private final String DOCUSIGN_LOGIN_ACCOUNTS_TEXT     = 'loginAccounts';
	private final String DOCUSIGN_BASE_URL_TEXT           = 'baseUrl';
	private final String DOCUSIGN_ACCOUNT_ID_TEXT         = 'accountId';
	private final String DOCUSIGN_EMAIL_SUBJECT           = 'emailSubject';
	private final String DOCUSIGN_EMAIL_BLURB             = 'emailBlurb';
	private final String DOCUSIGN_STATUS                  = 'status';
	private final String DOCUSIGN_BRAND_ID                = 'brandId';
	private final String DOCUSIGN_COMPOSITE_TEMPLATES     = 'compositeTemplates';
	private final String DOCUSIGN_SERVER_TEMPLATES        = 'serverTemplates';
	private final String DOCUSIGN_SEQUENCE                = 'sequence';
	private final String DOCUSIGN_TEMPLATE_ID             = 'templateId';
	private final String DOCUSIGN_INLINE_TEMPLATE         = 'inlineTemplates';
	private final String DOCUSIGN_RECIPIENTS              = 'recipients';
	private final String DOCUSIGN_SIGNERS                 = 'signers';
	private final String DOCUSIGN_EMAIL                   = 'email';
	private final String DOCUSIGN_NAME                    = 'name';
	private final String DOCUSIGN_RETURN_URL              = 'returnUrl';
	private final String DOCUSIGN_RECIPIENT_ID            = 'recipientId';
	private final String DOCUSIGN_ROLE_NAME               = 'roleName';
	private final String DOCUSIGN_ROUTING_ORDER           = 'routingOrder';
	private final String DOCUSIGN_CLIENT_USER_ID          = 'clientUserId';
	private final String DOCUSIGN_EMBEDDED_RECIPIENT_URL  = 'embeddedRecipientStartURL';
	private final String DOCUSIGN_SIGN_AT_DOCUSIGN        = 'SIGN_AT_DOCUSIGN';
	private final String DOCUSIGN_EMAIL_NOTIFICATION      = 'emailNotification';
	private final String DOCUSIGN_EMAIL_BODY              = 'emailBody';
	private final String DOCUSIGN_SUPPORTED_LANGUAGE      = 'supportedLanguage';
	private final String DOCUSIGN_TABS                    = 'tabs';
	private final String DOCUSIGN_TEXT_TABS               = 'textTabs';
	private final String DOCUSIGN_NUMBER_TABS             = 'numberTabs';
	private final String DOCUSIGN_TAB_LABEL               = 'tabLabel';
	private final String DOCUSIGN_VALUE                   = 'value';
	private final String DOCUSIGN_SIGNER                  = 'Signer';
	private final String DOCUSIGN_LABEL_START             = '\\*';
	private final String DOCUSIGN_ENVELOPE_PATH           = '/envelopes';
	private final String DOCUSIGN_VIEW_RECIPIENT_PATH     = '/views/recipient';
	private final String DOCUSIGN_DOCUMENTS_COMBINED_PATH = '/documents/combined';
	private final String DOCUSIGN_ENVELOPE_ID             = 'envelopeId';
	private final String DOCUSIGN_URL                     = 'url';
	private final String DOCUSIGN_SENT                    = 'sent';
	private final String DOCUSIGN_LANGUAGE_ENGLISH        = 'en';
	private final String DOCUSIGN_RESEND                  = '/recipients?resend_envelope=true';
	private final String STATUS_SIGN                      = 'Sign';
	private final String STATUS_FINISH                    = 'Finish';
	private final String STATUS_EMAIL                     = 'Email';
	private final String STRING_TYPE                      = 'String';
	private final String INTEGER_TYPE                     = 'Integer';
	private final String DOUBLE_TYPE                      = 'Double';
	private final String PATH_SEPERATOR                   = '/';
	private final String QUERY_PARAM_START                = '?';
	private final String INTEGER_ONE                      = '1';
	private final String COMPLETED_DOCUMENT               = 'Completed Docusign Document';
	private final String COMPLETED                        = 'completed';

	public DocusignOptions options {get; set;}
	public String authentication {get; set;}
	public String pathIdentifier {get; set;}
	public Id recordId {get; set;}
	public Contact currentContact {get; set;}
	public List<String> templateIds {get; set;}
	public Map<String, List<FieldMappingWrapper>> fieldNameToValuesMappings {get; set;}
	public List<Docusign_Field_Mappings__c> docusignFieldMapping {get; set;}
	public DocusignRequest dsRequest {get; set;}

	public Docusign(){
		this.options = new DocusignOptions();
	}

	public Docusign(Id recordId, String envelopeId, String pathIdentifier, List<String> templateIds, Contact currentContact, String returnURL){
		this.options = new DocusignOptions();
		options.returnURL = returnURL;
		this.pathIdentifier = pathIdentifier;
		this.templateIds = templateIds;
		this.currentContact = currentContact;
		this.options.envelopeId = envelopeId;
		this.recordId = recordId;
		this.docusignFieldMapping = Docusign_Field_Mappings__c.getAll().values();
		fieldNameToValuesMappings = getFieldMappingValues();
	}

	/**
	 * createEnvelope
	 * @description Creates the enevelope for the document.
	 * @author Thomas Tran, Traction on Demand
	 * @date 01-23-2017
	 */
	public String createEnvelope(){
		if(options.envelopeId != null){
			return options.envelopeId;
		}

		dsRequest = createRequest(POST_TEXT, DOCUSIGN_ENVELOPE_PATH)
			.withBody(buildEnvelopeRequest())
			.execute();
		Map<String, Object> responseBodyMap = dsRequest.getResponseBodyMap();

		options.envelopeId = String.valueOf(responseBodyMap.get(DOCUSIGN_ENVELOPE_ID));

		return options.envelopeId;
	}

	/**
	 * getPostRecipientView
	 * @description Retrieves the URL for the envelope if the status is SENT
	 * @author Thomas Tran, Traction on Demand
	 * @date 01-23-2017
	 */
	public String getPostRecipientView(){
		dsRequest = createRequest(POST_TEXT, DOCUSIGN_ENVELOPE_PATH + PATH_SEPERATOR + createEnvelope() + DOCUSIGN_VIEW_RECIPIENT_PATH)
			.withBody(buildPostRecipientViewRequest())
			.execute();
		Map<String, Object> responseBodyMap = dsRequest.getResponseBodyMap();
		
		options.postRecipientViewURL = String.valueOf(responseBodyMap.get(DOCUSIGN_URL));

		return options.postRecipientViewURL;
	}

	/**
	 * getEnvelopeDocuments
	 * @description Creates attachment against of the blol returned by docusign.
	 * @author Thomas Tran, Traction on Demand
	 * @date 02-07-2017
	 */
	public Attachment getEnvelopeDocuments(){
		dsRequest = createRequest(GET_TEXT, DOCUSIGN_ENVELOPE_PATH + PATH_SEPERATOR + createEnvelope() + DOCUSIGN_DOCUMENTS_COMBINED_PATH, false)
			.execute();
		HttpResponse response = dsRequest.getResponse();
		Attachment document = new Attachment();
		
		document.body = response.getBodyAsBlob();
		document.Name = COMPLETED_DOCUMENT;
		document.ContentType = 'application/pdf';
		document.ParentId = recordId;

		return document;
	}

	/**
	 * getListOfEnvelopeBasedOnStatus
	 * @description Retrive a list of envelope ids based on status
	 */
	public Set<String> getListOfEnvelopeBasedOnStatus(String envelopeIds, String status) {
		Set<String> completedEnvelopeIds = new Set<String>();
		dsRequest = createRequest(GET_TEXT, DOCUSIGN_ENVELOPE_PATH + '?envelope_ids=' + envelopeIds + '&status=' + status)
			.execute();
		Map<String, Object> responseBodyMap = dsRequest.getResponseBodyMap();

		List<Object> envelopes = (List<Object>) responseBodyMap.get('envelopes');

		for(Object envelope : envelopes){
			completedEnvelopeIds.add(String.valueOf(((Map<String, Object>) envelope).get(DOCUSIGN_ENVELOPE_ID)));
		}

		return completedEnvelopeIds;
	}

	/**
     * resendEnvelope
     * @description Resend existing envelope
     * @author Thomas Tran, Traction on Demand
     * @date 03-04-2019
     */
	public void resendEnvelope(){
		dsRequest = createRequest(PUT_TEXT, DOCUSIGN_ENVELOPE_PATH + PATH_SEPERATOR + createEnvelope() + DOCUSIGN_RESEND)
			.withBody(buildSignerRequest())
			.execute();
	}


	/**
	 * buildEnvelopeRequest
	 * @description Builds the json string that is sent to docusign.
	 * @author Thomas Tran, Traction on Demand
	 * @date 01-19-2017
	 */
	private String buildEnvelopeRequest(){
		String emailSubject = currentContact.Name + ' - ' + System.Label.Docusign_Email_Subject;

		JSONGenerator generator = JSON.createGenerator(true);

		generator.writeStartObject();
			generator.writeStringField(DOCUSIGN_EMAIL_SUBJECT, emailSubject);
			generator.writeStringField(DOCUSIGN_STATUS, DOCUSIGN_SENT);

			if(!templateIds.isEmpty() && templateIds.size() > 0){
				generator.writeFieldName(DOCUSIGN_COMPOSITE_TEMPLATES);
				generator.writeStartArray();

				for(Integer i = 0; i < templateIds.size(); i++){
					generator.writeStartObject();
						generator.writeFieldName(DOCUSIGN_SERVER_TEMPLATES);
						generator.writeStartArray();
                            generator.writeStartObject();    
                                generator.writeStringField(DOCUSIGN_SEQUENCE, String.valueOf(i + 1));
					if(String.isBlank(templateIds[i])) {
						throw new UnsupportedOperationException('Invalid template id: "' + templateIds[i] + '"');
					}
                                generator.writeStringField(DOCUSIGN_TEMPLATE_ID, templateIds[i]); 
                            generator.writeEndObject();
                        generator.writeEndArray();

                        generator.writeFieldName(DOCUSIGN_INLINE_TEMPLATE);
                        generator.writeStartArray();
                            generator.writeStartObject();    
                                generator.writeStringField(DOCUSIGN_SEQUENCE, String.valueOf(i + 1));
                                generator.writeFieldName(DOCUSIGN_RECIPIENTS);
                                generator.writeStartObject();
                                	generator.writeFieldName(DOCUSIGN_SIGNERS);
                                	generator.writeStartArray();
                                	if(String.isNotBlank(currentContact.Name) && String.isNotBlank(currentContact.Email)){
                                		generator.writeStartObject();
                                			generator.writeStringField(DOCUSIGN_EMAIL, currentContact.Email);
                                			generator.writeStringField(DOCUSIGN_NAME, currentContact.Name);
                                			generator.writeStringField(DOCUSIGN_RETURN_URL, options.returnURL);
                                			generator.writeStringField(DOCUSIGN_RECIPIENT_ID, INTEGER_ONE);
                                			generator.writeStringField(DOCUSIGN_ROLE_NAME, DOCUSIGN_SIGNER + ' ' + INTEGER_ONE);
                                			generator.writeStringField(DOCUSIGN_ROUTING_ORDER, INTEGER_ONE);
                                			// TOD029-18659
                                			// To designate a recipient, should use same clientUserId, name and email as unique value for the envelope either via Email or via Sign
                                			// https://developers.docusign.com/docs/esign-rest-api/esign101/concepts/embedding/
                                			generator.writeStringField(DOCUSIGN_CLIENT_USER_ID, INTEGER_ONE);
                                			// Specifying a clientUserId causes the recipient to be an "embedded" signer 
                                			// which leads to unable to send email to recipient
                                			// Specifying an embeddedRecipientStartURL causes the recipient to also receive an official DocuSign email inviting them to sign the documents.
                                			// https://stackoverflow.com/questions/21303672/can-we-enable-both-embedded-and-remote-sign-in-docusign-api-using-c/28815901#28815901
                                			generator.writeStringField(DOCUSIGN_EMBEDDED_RECIPIENT_URL, DOCUSIGN_SIGN_AT_DOCUSIGN);
                                			

                                			generator.writeFieldName(DOCUSIGN_EMAIL_NOTIFICATION);
                                			generator.writeStartObject();
                                				generator.writeStringField(DOCUSIGN_EMAIL_BODY, '');
                                				generator.writeStringField(DOCUSIGN_EMAIL_SUBJECT, emailSubject);
                                				generator.writeStringField(DOCUSIGN_SUPPORTED_LANGUAGE, DOCUSIGN_LANGUAGE_ENGLISH);

                                			generator.writeEndObject();

                                			
                                			//Text field assignment
                                			generator.writeFieldName(DOCUSIGN_TABS);
                                			generator.writeStartObject();
                                				generator.writeFieldName(DOCUSIGN_TEXT_TABS);
                                				generator.writeStartArray();

                                				for(Docusign_Field_Mappings__c field : docusignFieldMapping){
													if(fieldNameToValuesMappings.isEmpty()){
														continue;
													}

													List<FieldMappingWrapper> wrapperObj = fieldNameToValuesMappings.get(field.Sobject_Type__c);

													if(wrapperObj == null){
														continue;
													}

                                					if((field.Template_Id__c != templateIds[i]) && !(field.Data_Type__c).equals(STRING_TYPE) && !fieldNameToValuesMappings.containsKey(field.Sobject_Type__c)){
                                						continue;
                                					}

                                					for(FieldMappingWrapper wrapper : wrapperObj){
                                						if(wrapper.getMatch(field.Source_Field__c)){
                                							generator.writeStartObject();
		                                						generator.writeStringField(DOCUSIGN_TAB_LABEL, DOCUSIGN_LABEL_START + field.Target_Field__c);
		                                						generator.writeStringField(DOCUSIGN_VALUE, String.valueOf(wrapper.value));
		                                					generator.writeEndObject();

		                                					break;
                                						}
                                					}
                                				}

                                				generator.writeEndArray();
                                			generator.writeEndObject();

                                			//Numeric field assignment
                                			generator.writeFieldName(DOCUSIGN_TABS);
                                			generator.writeStartObject();
                                				generator.writeFieldName(DOCUSIGN_NUMBER_TABS);
                                				generator.writeStartArray();

                                				for(Docusign_Field_Mappings__c field : docusignFieldMapping){
													if(fieldNameToValuesMappings.isEmpty()){
														continue;
													}

													List<FieldMappingWrapper> wrapperObj = fieldNameToValuesMappings.get(field.Sobject_Type__c);

													if(wrapperObj == null){
														continue;
													}

                                					if((field.Template_Id__c != templateIds[i]) && (!(field.Data_Type__c).equals(INTEGER_TYPE) || !(field.Data_Type__c).equals(DOUBLE_TYPE))
                                						&& !fieldNameToValuesMappings.containsKey(field.Sobject_Type__c)){
                                						continue;
                                					}

                                					for(FieldMappingWrapper wrapper : wrapperObj){
                                						if(wrapper.getMatch(field.Source_Field__c)){
                                							generator.writeStartObject();
		                                						generator.writeStringField(DOCUSIGN_TAB_LABEL, DOCUSIGN_LABEL_START + field.Target_Field__c);
		                                						generator.writeStringField(DOCUSIGN_VALUE, String.valueOf(wrapper.value));
		                                					generator.writeEndObject();

		                                					break;
                                						}
                                					}
                                				}

                                				generator.writeEndArray();
                                			generator.writeEndObject();

                                		generator.writeEndObject();	
                                	}
                                	generator.writeEndArray();
                               	generator.writeEndObject();
                            generator.writeEndObject();
                        generator.writeEndArray();
					generator.writeEndObject();
				}

				generator.writeEndArray();
			}

		generator.writeEndObject();

		return generator.getAsString();
	}

	private String buildSignerRequest(){
		JSONGenerator generator = JSON.createGenerator(true);

		generator.writeStartObject();
		generator.writeFieldName(DOCUSIGN_SIGNERS);
		generator.writeStartArray();
		if(String.isNotBlank(currentContact.Name) && String.isNotBlank(currentContact.Email)){
			generator.writeStartObject();
			generator.writeStringField(DOCUSIGN_EMAIL, currentContact.Email);
			generator.writeStringField(DOCUSIGN_NAME, currentContact.Name);
			generator.writeStringField(DOCUSIGN_RECIPIENT_ID, INTEGER_ONE);
			generator.writeEndObject();
		}
		generator.writeEndArray();
		generator.writeEndObject();

		return generator.getAsString();
	}

	/**
	 * buildPostRecipientViewRequest
	 * @description Generates the body required to get the URL.
	 * @author Thomas Tran, Traction on Demand
	 * @date 01-23-2107
	 */
	private String buildPostRecipientViewRequest(){
		return JSON.serialize(new DocusignPostRecipientView(options.returnURL, currentContact.Name, currentContact.Email, STATUS_EMAIL, INTEGER_ONE));
	}

	/**
	 * getFieldMappingValues
	 * @description Generate map of all the values
	 * @author Thomas Tran, Traction on Demand
	 * @date 02-08-2017
	 */
	private Map<String, List<FieldMappingWrapper>> getFieldMappingValues(){
		Map<String, List<FieldMappingWrapper>> objectToFieldToValueMap = new Map<String, List<FieldMappingWrapper>>();
		Map<String, Set<String>> objectToFieldMap = new Map<String, Set<String>>();
		Map<String, Schema.SObjectType> globalDescribeMap = Schema.getGlobalDescribe();
		
		for(Docusign_Field_Mappings__c fieldMapping : docusignFieldMapping){
			Boolean hasTargetField = String.isNotBlank(fieldMapping.Target_Field__c);
			Boolean hasSourceField = String.isNotBlank(fieldMapping.Source_Field__c);
			Boolean hasDataTypeField = String.isNotBlank(fieldMapping.Data_Type__c);
			Boolean hasTemplateIdField = String.isNotBlank(fieldMapping.Template_Id__c);
			Boolean hasSObjectTypeField = String.isNotBlank(fieldMapping.Sobject_Type__c);

			if(!(hasTargetField && hasSourceField && hasDataTypeField && hasTemplateIdField && hasSObjectTypeField)){
				continue;
			}

			if(!objectToFieldMap.containsKey(fieldMapping.Sobject_Type__c)){
				objectToFieldMap.put(fieldMapping.Sobject_Type__c, new Set<String>());
				objectToFieldToValueMap.put(fieldMapping.Sobject_Type__c, new List<FieldMappingWrapper>());
			}

			objectToFieldMap.get(fieldMapping.Sobject_Type__c).add(fieldMapping.Source_Field__c);
		}

		for(String objectName : objectToFieldMap.keySet()){
			String queryString = 'SELECT ';
	
			for(String fieldName : objectToFieldMap.get(objectName)){
				if(!queryString.equals('SELECT ')){
					queryString += ', ';
				}
				
				queryString += fieldName;
			}
			
			queryString += ' FROM ' + objectName + ' WHERE Id = :recordId';
			
			List<SObject> sobjects = Database.query(queryString);

			if(sobjects.isEmpty()){
				continue;
			}
			
	        SObject currentObj = sobjects[0];

	        for(String fieldName : objectToFieldMap.get(objectName)){
	        	if((fieldName).contains('__r.')){
	        		String relationshipFieldName = (fieldName).substringAfterLast('__r.');
	        		String relationship = (fieldName).substringBeforeLast('.' + relationshipFieldName);

                    if(currentObj.getSObject(relationship) != null){
                    	if(currentObj.getSObject(relationship).get(relationshipFieldName) != null){
                        	objectToFieldToValueMap.get(objectName).add(new FieldMappingWrapper(fieldName, currentObj.getSObject(relationship).get(relationshipFieldName)));
                    	}
                    }
	        	} else{
	        		if(currentObj.get(fieldName) != null){
		        		objectToFieldToValueMap.get(objectName).add(new FieldMappingWrapper(fieldName, currentObj.get(fieldName)));
		        	}
	        	}
	        }
		}

		return objectToFieldToValueMap;
	}


	/**
	 * DocusignPostRecipientView
	 * @description Wrapper class for PostRecipientView request body.
	 * @author Thomas Tran, Traction on Demand
	 * @date 01-23-2017
	 */
	public class DocusignPostRecipientView{
		public String returnURL {get; set;}
		public String authenticationMethod {get; set;}
		public String email {get; set;}
		public String userName {get; set;}
		public String clientUserId {get; set;}

		public DocusignPostRecipientView(String returnURL, String signerName, String signerEmail, String authenticationMethod, String clientUserId){
			this.returnURL = returnURL;
			this.userName = signerName;
			this.email = signerEmail;
			this.authenticationMethod = authenticationMethod;
			this.clientUserId = clientUserId;
		}
	}

	/**
	 * FieldMappingWrapper
	 * @description Wrapper class for record field name and value.
	 * @author Thomas Tran, Traction on Demand
	 * @date 01-23-2017
	 */
	public class FieldMappingWrapper{
		public String fieldName {get; set;}
		public Object value {get; set;}

		public FieldMappingWrapper(String fieldName, Object value){
			this.fieldName = fieldName;
			this.value = value;
		}

		public Boolean getMatch(String comparisonFieldName){
			return (fieldName).equals(comparisonFieldName);
		}
	}

	public class DocusignResponse{
		public String envelopeId {get; set;}
	}
	public DocusignRequest createRequest(String method, String path){
		return createRequest(method, path, true);
	}
	/**
	 * create new one if there is no DocusignRequest instance
	 * otherwice should call instance method `but` to create a new one
	 * purpose of this is to reuse oAuth object, so avoid making a api callout to obtain access token every time 
	 * Note: the access token should be upsert to custom setting manually when all api callouts are done
	 * so next time in front end making another request, it will use the one saved in Docusign_Access_Token__c
	 * See `DocusignAccessToken.doUpsert`
	 */
	public DocusignRequest createRequest(String method, String path, Boolean deserializeJSON){
		if(dsRequest == null){
			this.dsRequest = new DocusignRequest(method, path, deserializeJSON);
		}else{
			this.dsRequest = dsRequest.but(method, path, deserializeJSON);
		}
		return this.dsRequest;
	}
	
	public void upsertAccessTokenSetting(){
		if(dsRequest != null){
			dsRequest.upsertAccessTokenSetting();
		}
	}
}