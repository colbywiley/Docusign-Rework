public with sharing class WaiverEmailService {

    public class SendResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String  message;
    }

    /**
     * Sends the Smartwaiver email using a Classic email template chosen by contract context:
     *  - If TREX1__Registration__c is populated: Smartwaiver_Config__c.Registration_Email_Template_Id__c
     *  - Else if TREX1__Membership__c is populated: Smartwaiver_Config__c.Classic_Email_Template_Id__c
     *
     * Also:
     *  - If a matching active User exists for the Contact's email, send to that User (quota-friendly)
     *  - Otherwise send to the Contact's email
     *  - Optionally applies Org-Wide Email From address
     *  - Replaces {{WAIVER_URL}} and {{LOGO_URL}} in rendered HTML/Text
     */
    @AuraEnabled
    public static SendResult sendUsingConfiguredTemplate(Id contractId, Id contactId, String waiverUrl) {
        SendResult out = new SendResult();
        try {
            if (contractId == null)  throw new AuraHandledException('Missing Contract Id.');
            if (contactId == null)   throw new AuraHandledException('Missing Contact Id.');
            if (String.isBlank(waiverUrl)) throw new AuraHandledException('Missing waiver URL.');

            // 1) Load Contact for email + user lookup
            Contact c = [
                SELECT Id, Email, FirstName, LastName
                FROM Contact
                WHERE Id = :contactId
                LIMIT 1
            ];
            if (String.isBlank(c.Email)) {
                throw new AuraHandledException('Recipient contact has no email.');
            }

            // 2) Try to find an active User with the same email (Experience Cloud or internal)
            User u = tryFindActiveUserByEmail(c.Email);

            // 3) Resolve settings (Template + Org-Wide + Logo URL)
            Smartwaiver_Config__c cfg = Smartwaiver_Config__c.getOrgDefaults();
            if (cfg == null) {
                throw new AuraHandledException('Smartwaiver_Config org defaults not found.');
            }

            Id templateId = pickTemplateIdForContract(contractId, cfg);
            String logoUrl = (cfg != null) ? String.valueOf(cfg.Email_Logo_Url__c) : null;
            Id owEmailId = getOrgWideEmailAddressId(cfg); // may be null

            // 4) Render template in context (Contact as WhoId, Contract as WhatId)
            //    NOTE: Do NOT set setTemplateId on the outbound email; we render first, then set bodies.
            Messaging.SingleEmailMessage rendered =
                Messaging.renderStoredEmailTemplate(templateId, c.Id, contractId);

            String subj = rendered.getSubject();
            String html = rendered.getHtmlBody();
            String text = rendered.getPlainTextBody();

            // Token replacement for waiver link + logo
            html = replaceTokens(html, waiverUrl, logoUrl);
            text = replaceTokens(text, waiverUrl, logoUrl);

            // 5) Build & send
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setSaveAsActivity(false);

            if (u != null) {
                mail.setTargetObjectId(u.Id);
                mail.setTreatTargetObjectAsRecipient(true);
            } else {
                mail.setToAddresses(new String[]{ c.Email });
            }

            if (owEmailId != null) {
                mail.setOrgWideEmailAddressId(owEmailId);
            }

            if (!String.isBlank(subj)) mail.setSubject(subj);
            if (!String.isBlank(html)) mail.setHtmlBody(html);
            if (!String.isBlank(text)) mail.setPlainTextBody(text);

            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });

            out.success = true;
            out.message = (u != null ? 'Sent to matching User.' : 'Sent to Contact email.')
                        + (owEmailId != null ? ' (Org-Wide Email applied)' : '');
            return out;

        } catch (Exception e) {
            out.success = false;
            out.message = e.getMessage();
            return out;
        }
    }

    // -------------------
    // Template selection
    // -------------------
    private static Id pickTemplateIdForContract(Id contractId, Smartwaiver_Config__c cfg) {
        TREX1__Contract_And_Form__c caf = [
            SELECT Id, TREX1__Membership__c, TREX1__Registration__c
            FROM TREX1__Contract_And_Form__c
            WHERE Id = :contractId
            LIMIT 1
        ];

        // Priority: Registration, then Membership
        String chosen;
        if (caf.TREX1__Registration__c != null) {
            chosen = cfg != null ? String.valueOf(cfg.Registration_Email_Template_Id__c) : null;
            if (String.isBlank(chosen)) {
                throw new AuraHandledException('Registration email template Id not configured in Smartwaiver_Config.Registration_Email_Template_Id__c.');
            }
        } else if (caf.TREX1__Membership__c != null) {
            chosen = cfg != null ? String.valueOf(cfg.Classic_Email_Template_Id__c) : null;
            if (String.isBlank(chosen)) {
                throw new AuraHandledException('Membership email template Id not configured in Smartwaiver_Config.Classic_Email_Template_Id__c.');
            }
        } else {
            // Neither relationship present — force an explicit choice to avoid surprises
            throw new AuraHandledException('Cannot determine email template: Contract has neither Membership nor Registration linked.');
        }

        try {
            return (Id) chosen;
        } catch (Exception e) {
            throw new AuraHandledException('Configured email template value is not a valid Id: ' + chosen);
        }
    }

    // -------------------
    // From address (OWEA)
    // -------------------
    private static Id getOrgWideEmailAddressId(Smartwaiver_Config__c cfg) {
        if (cfg == null || String.isBlank(cfg.Org_Wide_Email_Address__c)) return null;

        String raw = cfg.Org_Wide_Email_Address__c.trim();

        if (isLikelySfId(raw)) {
            List<OrgWideEmailAddress> x = [
                SELECT Id FROM OrgWideEmailAddress WHERE Id = :raw LIMIT 1
            ];
            if (!x.isEmpty()) return x[0].Id;
            throw new AuraHandledException('Org-Wide Email Id not found: ' + raw);
        }

        List<OrgWideEmailAddress> ow = [
            SELECT Id, Address
            FROM OrgWideEmailAddress
            WHERE Address = :raw
            LIMIT 1
        ];
        if (ow.isEmpty()) {
            throw new AuraHandledException('Org-Wide Email not found for address: ' + raw);
        }
        return ow[0].Id;
    }

    // -------------------
    // Utilities
    // -------------------
    private static User tryFindActiveUserByEmail(String email) {
        if (String.isBlank(email)) return null;
        List<User> users = [
            SELECT Id, Email, IsActive, UserType, LastLoginDate
            FROM User
            WHERE IsActive = true AND Email = :email
            ORDER BY LastLoginDate DESC NULLS LAST
            LIMIT 1
        ];
        return users.isEmpty() ? null : users[0];
    }

    private static Boolean isLikelySfId(String s) {
        if (String.isBlank(s)) return false;
        Integer len = s.length();
        if (len != 15 && len != 18) return false;
        for (Integer i = 0; i < len; i++) {
            String ch = s.substring(i, i+1);
            if (!((ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9'))) return false;
        }
        return true;
    }

    private static String replaceTokens(String input, String waiverUrl, String logoUrl) {
        if (String.isBlank(input)) return input;
        if (!String.isBlank(waiverUrl)) input = input.replace('{{WAIVER_URL}}', waiverUrl);
        if (!String.isBlank(logoUrl))   input = input.replace('{{LOGO_URL}}',   logoUrl);
        return input;
    }
}
