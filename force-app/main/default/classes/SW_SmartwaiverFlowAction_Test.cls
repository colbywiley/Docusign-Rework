@IsTest
private class SW_SmartwaiverFlowAction_Test {
    // Mocking the Smartwaiver API callout
    private class MockSmartwaiverCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);

            // Build a fake JSON payload
            Map<String, Object> waiver = new Map<String, Object>{
                'email'                   => 'john.doe@example.com',
                'pdf'                     => 'PDF_RAW_DATA',
                'autoTag'                 => 'aTag123',
                'emergencyContactName'    => 'Jane Smith',
                'emergencyContactPhone'   => '555-1234',
                'addressLineOne'          => '123 Main St',
                'addressLineTwo'          => 'Suite 100',
                'addressCity'             => 'Metropolis',
                'addressState'            => 'CA',
                'addressZip'              => '90210',
                'addressCountry'          => 'USA',
                // no guardian => adult comes from participants
                'participants'            => new List<Object>{
                    new Map<String,Object>{
                        'firstName'  => 'John',
                        'middleName' => 'Q',
                        'lastName'   => 'Doe',
                        'dob'        => '1980-01-01',
                        'isMinor'    => false
                    },
                    new Map<String,Object>{
                        'firstName'  => 'Little',
                        'lastName'   => 'Kid',
                        'dob'        => '2015-05-05',
                        'isMinor'    => true
                    }
                }
            };
            Map<String,Object> wrapper = new Map<String,Object>{ 'waiver' => waiver };
            res.setBody(JSON.serialize(wrapper));
            return res;
        }
    }

    @IsTest static void testFetchWaivers_ParsesAllFields() {
        // Register our mock
        Test.setMock(HttpCalloutMock.class, new MockSmartwaiverCallout());

        // Prepare input: one wrapper with retrievePdf = true
        SW_SmartwaiverFlowAction.InputWrapper req = new SW_SmartwaiverFlowAction.InputWrapper();
        req.waiverId    = 'TestWaiver123';
        req.retrievePdf = true;

        Test.startTest();
            List<SW_SmartwaiverFlowAction.OutputWrapper> results =
                SW_SmartwaiverFlowAction.fetchWaivers(new List<SW_SmartwaiverFlowAction.InputWrapper>{ req });
        Test.stopTest();

        // We expect exactly one OutputWrapper
        System.assertEquals(1, results.size());

        SW_SmartwaiverFlowAction.OutputWrapper out = results[0];

        // Top‐level fields
        System.assertEquals('PDF_RAW_DATA',        out.pdfValue);
        System.assertEquals('aTag123',             out.autoTagValue);
        System.assertEquals('Jane',                out.emergencyContactFirstName);
        System.assertEquals('Smith',               out.emergencyContactLastName);
        System.assertEquals('555-1234',            out.emergencyContactPhone);

        // Adult Contact (should come from the non-minor participant)
        Contact adult = out.adultContactRecordVar;
        System.assertEquals('john.doe@example.com', adult.Email);
        System.assertEquals('John',                 adult.FirstName);
        System.assertEquals('Q',                    adult.MiddleName);
        System.assertEquals('Doe',                  adult.LastName);
        System.assert(adult.MailingStreet.contains('123 Main St'));
        System.assertEquals('Metropolis',           adult.MailingCity);
        System.assertEquals('CA',                   adult.MailingState);

        // Participant contacts: two entries
        List<Contact> parts = out.participantContactRecordCollectionVar;
        System.assertEquals(2, parts.size());
        // Check the first participant
        Contact p0 = parts[0];
        System.assertEquals('John', p0.FirstName);
        System.assertEquals('Doe',  p0.LastName);
        // Check the minor
        Contact p1 = parts[1];
        System.assertEquals('Little', p1.FirstName);
        System.assertEquals('Kid',    p1.LastName);
    }
}