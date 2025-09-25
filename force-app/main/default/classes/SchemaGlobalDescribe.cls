public with sharing class SchemaGlobalDescribe {
    // ===== Invocable request & response payloads =====
    public class Request {
        @InvocableVariable(required=true)
        public String recordIdOrPrefix;
    }
    public class Response {
        @InvocableVariable
        public String objectApiName;
        @InvocableVariable
        public String objectLabel;
        @InvocableVariable
        public String keyPrefix;
        @InvocableVariable
        public String error;
    }

    // ===== Build a prefix → describe map once per transaction =====
    private static final Map<String, Schema.DescribeSObjectResult> DESCRIBE_BY_PREFIX = buildPrefixMap();
    private static Map<String, Schema.DescribeSObjectResult> buildPrefixMap() {
        Map<String, Schema.DescribeSObjectResult> m = new Map<String, Schema.DescribeSObjectResult>();
        for (Schema.SObjectType t : Schema.getGlobalDescribe().values()) {
            Schema.DescribeSObjectResult d = t.getDescribe();
            String p = d.getKeyPrefix();
            if (p != null) m.put(p, d);
        }
        return m;
    }

    @InvocableMethod(
        label='Find Object by Id or Key Prefix'
        description='Given a record Id (15/18 chars) or a 3-char key prefix, returns the matching object API name.'
        category='Utilities'
    )
    public static List<Response> findObjectByIdOrPrefix(List<Request> requests) {
        List<Response> out = new List<Response>();

        for (Request req : requests) {
            Response res = new Response();
            try {
                String input = (req == null) ? null : String.valueOf(req.recordIdOrPrefix).trim();
                if (String.isBlank(input) || input.length() < 3) {
                    res.error = 'Input must be a 3-char key prefix or a 15/18-char Id.';
                    out.add(res);
                    continue;
                }

                // Always just use the first 3 chars (works for full Ids and raw prefixes)
                String prefix = input.substring(0, 3);
                res.keyPrefix = prefix;

                Schema.DescribeSObjectResult d = DESCRIBE_BY_PREFIX.get(prefix);
                if (d != null) {
                    res.objectApiName = d.getName();
                    res.objectLabel   = d.getLabel();
                } else {
                    res.error = 'No object found for key prefix: ' + prefix;
                }
            } catch (Exception e) {
                res.error = e.getMessage();
            }
            out.add(res);
        }
        return out;
    }
}
