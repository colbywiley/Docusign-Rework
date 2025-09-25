public with sharing class SW_SmartwaiverFlowAction {

    /**
     * Inputs for Flow:
     *  1) waiverId   (String)
     *  2) retrievePdf (Boolean) - if true, append ?pdf=true to the endpoint
     */
    public class InputWrapper {
        @InvocableVariable(label='Waiver ID' required=true)
        public String waiverId;
        
        @InvocableVariable(label='Retrieve PDF?' description='If true, append ?pdf=true to the end of the URL.' required=true)
        public Boolean retrievePdf;
    }
    
    /**
     * Outputs for Flow:
     *  1) adultContactRecordVar   (Contact)
     *  2) participantContactRecordCollectionVar (List<Contact>)
     *  3) pdfValue               (String)
     *  4) autoTagValue           (String)
     *  5) emergencyContactFirstName (String)
     *  6) emergencyContactLastName  (String)
     *  7) emergencyContactPhone     (String)
     */
    public class OutputWrapper {
        @InvocableVariable(label='Adult Contact Record' 
                           description='A single Contact record for the adult signer.')
        public Contact adultContactRecordVar;
        
        @InvocableVariable(label='Participant Contact Records' 
                           description='A collection of Contact records for each participant.')
        public List<Contact> participantContactRecordCollectionVar;
        
        @InvocableVariable(label='PDF Value' 
                           description='Raw PDF string returned from Smartwaiver (if any).')
        public String pdfValue;

        @InvocableVariable(label='Auto Tag'
                           description='The autoTag field from the Smartwaiver JSON (e.g., \"aANcf0000002jqfGAA\").')
        public String autoTagValue;

        @InvocableVariable(label='Emergency Contact First Name'
                           description='Derived from emergencyContactName in the JSON.')
        public String emergencyContactFirstName;

        @InvocableVariable(label='Emergency Contact Last Name'
                           description='Derived from emergencyContactName in the JSON.')
        public String emergencyContactLastName;

        @InvocableVariable(label='Emergency Contact Phone'
                           description='From the emergencyContactPhone field in the JSON.')
        public String emergencyContactPhone;
    }
    
    /**
     * Main Invocable Method:
     * - Accepts a list of InputWrappers (each has waiverId + retrievePdf).
     * - Returns a list of OutputWrappers (one per input).
     */
    @InvocableMethod(label='Fetch Waiver Data from Smartwaiver' 
                     description='Calls the Smartwaiver API for each waiverId, optionally retrieving PDF if retrievePdf = true.')
    public static List<OutputWrapper> fetchWaivers(List<InputWrapper> requests) {
        
        List<OutputWrapper> results = new List<OutputWrapper>();
        
        for (InputWrapper req : requests) {
            // Prepare a default output
            OutputWrapper ow = new OutputWrapper();
            ow.adultContactRecordVar = new Contact();
            ow.participantContactRecordCollectionVar = new List<Contact>();
            ow.pdfValue = '';
            ow.autoTagValue = '';
            ow.emergencyContactFirstName = '';
            ow.emergencyContactLastName  = '';
            ow.emergencyContactPhone     = '';
            
            // If blank waiverId, skip
            if (String.isBlank(req.waiverId)) {
                results.add(ow);
                continue;
            }
            
            try {
                // 1) Build the endpoint
                // Named Credential base: callout:Smartwaiver_Named_Credential
                // Path: /waivers/{waiverId}
                // If retrievePdf == true, append "?pdf=true"
                String endpoint = 'callout:Smartwaiver_Named_Credential/waivers/' + req.waiverId;
                if (req.retrievePdf) {
                    endpoint += '?pdf=true';
                }
                
                HttpRequest httpReq = new HttpRequest();
                httpReq.setEndpoint(endpoint);
                httpReq.setMethod('GET');
                
                HttpResponse response = new Http().send(httpReq);
                
                if (response.getStatusCode() == 200) {
                    // Parse JSON
                    String responseBody = response.getBody();
                    Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
                    Map<String, Object> waiverMap = (Map<String, Object>) root.get('waiver');
                    
                    if (waiverMap != null) {
                        
                        // PDF
                        ow.pdfValue = (String) waiverMap.get('pdf');
                        
                        // autoTag
                        ow.autoTagValue = (String) waiverMap.get('autoTag');
                        
                        // emergency contact fields
                        String ecName  = (String) waiverMap.get('emergencyContactName');
                        String ecPhone = (String) waiverMap.get('emergencyContactPhone');
                        ow.emergencyContactPhone = ecPhone;
                        
                        // We'll do a simple split for first/last
                        // If there's a space, we treat first part as firstName, remainder as lastName
                        if (!String.isBlank(ecName)) {
                            List<String> nameParts = ecName.split(' ', 2);
                            if (nameParts.size() == 2) {
                                ow.emergencyContactFirstName = nameParts[0];
                                ow.emergencyContactLastName  = nameParts[1];
                            } else {
                                // If only one part, assume it's the first name
                                ow.emergencyContactFirstName = ecName;
                                ow.emergencyContactLastName  = '';
                            }
                        }
                        
                        // Build the Adult contact
                        Contact adultContact = new Contact();
                        
                        // Always set the adult's email from waiver.email
                        adultContact.Email = (String) waiverMap.get('email');
                        
                        Map<String, Object> guardianMap = (Map<String, Object>) waiverMap.get('guardian');
                        if (guardianMap != null) {
                            // Guardian => adult is the guardian
                            adultContact = buildAdultFromGuardian(guardianMap, adultContact);
                            
                        } else {
                            // Guardian is null => find an adult in participants
                            // Meanwhile, set address from top-level fields
                            adultContact.MailingStreet = combineLines(
                                (String) waiverMap.get('addressLineOne'), 
                                (String) waiverMap.get('addressLineTwo')
                            );
                            adultContact.MailingCity   = (String) waiverMap.get('addressCity');
                            adultContact.MailingState  = (String) waiverMap.get('addressState');
                            adultContact.MailingPostalCode = (String) waiverMap.get('addressZip');
                            adultContact.MailingCountry    = (String) waiverMap.get('addressCountry');
                        }
                        
                        // Build participant contacts
                        List<Object> participantsRaw = (List<Object>) waiverMap.get('participants');
                        List<Contact> participantContacts = new List<Contact>();
                        
                        if (participantsRaw != null) {
                            for (Object o : participantsRaw) {
                                Map<String, Object> pMap = (Map<String, Object>) o;
                                Contact pc = new Contact();
                                pc.FirstName  = (String) pMap.get('firstName');
                                pc.MiddleName = (String) pMap.get('middleName');
                                pc.LastName   = (String) pMap.get('lastName');
                                pc.Birthdate  = parseDate((String) pMap.get('dob'));
                                
                                participantContacts.add(pc);
                                
                                // If guardian is null, an adult must be in participants
                                Boolean isMinor = pMap.containsKey('isMinor') ? (Boolean) pMap.get('isMinor') : false;
                                if (guardianMap == null && !isMinor) {
                                    // This participant is the adult
                                    adultContact.FirstName  = pc.FirstName;
                                    adultContact.MiddleName = pc.MiddleName;
                                    adultContact.LastName   = pc.LastName;
                                    adultContact.Birthdate  = pc.Birthdate;
                                }
                            }
                        }
                        
                        ow.adultContactRecordVar = adultContact;
                        ow.participantContactRecordCollectionVar = participantContacts;
                    }
                    
                } else {
                    // Non-200
                    System.debug('Smartwaiver callout failed: ' + response.getStatusCode() 
                                 + ' - ' + response.getBody());
                }
                
            } catch (Exception ex) {
                System.debug('Exception in fetchWaivers for ID '+req.waiverId+': ' + ex);
            }
            
            results.add(ow);
        }
        
        return results;
    }
    
    /**
     * Helper method to fill adultContact from guardian fields.
     * We pass the existing Contact so we can preserve the email we set above.
     */
    private static Contact buildAdultFromGuardian(Map<String,Object> gMap, Contact c) {
        // Names
        c.FirstName  = (String) gMap.get('firstName');
        c.MiddleName = (String) gMap.get('middleName');
        c.LastName   = (String) gMap.get('lastName');
        
        // If there's a dob
        String dobStr = (String) gMap.get('dob');
        c.Birthdate   = parseDate(dobStr);
        
        // Guardian address
        String street = (String) gMap.get('guardianAddress');
        String street2 = (String) gMap.get('guardianAddress2');
        c.MailingStreet = combineLines(street, street2);
        c.MailingCity   = (String) gMap.get('guardianCity');
        c.MailingState  = (String) gMap.get('guardianState');
        c.MailingPostalCode = (String) gMap.get('guardianZip');
        c.MailingCountry    = (String) gMap.get('guardianCountry');
        
        // We do NOT overwrite c.Email here. It's from the top-level waiver.
        
        return c;
    }
    
    // Combine 2 lines into a single multiline string
    private static String combineLines(String line1, String line2) {
        if (String.isBlank(line1)) line1 = '';
        if (String.isBlank(line2)) return line1;
        return line1 + '\n' + line2;
    }
    
    // Parse a date in YYYY-MM-DD
    private static Date parseDate(String dateStr) {
        if (String.isBlank(dateStr)) return null;
        try {
            return Date.valueOf(dateStr);
        } catch (Exception e) {
            System.debug('parseDate error: '+e);
            return null;
        }
    }
}