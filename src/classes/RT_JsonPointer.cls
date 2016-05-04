/**
 * Implementation of JSON Pointer specification:
 * http://tools.ietf.org/html/draft-ietf-appsawg-json-pointer-03
 * Pointer instances can be used to locate logical JSON nodes for things like
 * tree traversal (see JavaNode#at).
 */
public class RT_JsonPointer {
    /** Marker instance used to represent segment that matches current
     *  node or position (that is, returns true for #matches()).
     */
    @testVisible
    private final static RT_JsonPointer EMPTY = new RT_JsonPointer();
    
    /** Reference to rest of the pointer beyond currently matching
     *  segment (if any); null if this pointer refers to the matching segment.
     */
    private final RT_JsonPointer nextSegment;
    
    /** Reference from currently matching segment (if any) to node
     *  before leaf. Lazily constructed if/as needed.
     */
    private RT_JsonPointer head;
    
    /** We will retain representation of the pointer, as a String,
     *  so that #toString should be as efficient as possible.
     */
    private final String asString;
    
    private final String matchingPropertyName;
    
    private final Integer matchingElementIndex;
    
    /** Constructor used for creating "empty" instance, used to represent
     *  state that matches current node.
     */
    private RT_JsonPointer() {
        nextSegment = null;
        matchingPropertyName = '';
        matchingElementIndex = -1;
        asString = '';
    }
    
    /** Constructor used for creating non-empty Segments
     */
    private RT_JsonPointer(String fullString, String segment, RT_JsonPointer next) {
        asString = fullString;
        nextSegment = next;
        // Ok; may always be a property
        matchingPropertyName = segment;
        // but could be an index, if parsable
        matchingElementIndex = parseIndex(segment);
    }
    
    private RT_JsonPointer(String fullString, String segment, Integer matchIndex, RT_JsonPointer next) {
        asString = fullString;
        nextSegment = next;
        matchingPropertyName = segment;
        matchingElementIndex = matchIndex;
    }
    
    /**
     * Factory method that parses given input and construct matching pointer
     * instance, if it represents a valid JSON Pointer: if not, a
     * IllegalArgumentException is thrown.
     */
    public static RT_JsonPointer compile(String input) {
        // First quick checks for well-known 'empty' pointer
        if (String.isBlank(input)) {
            return EMPTY;
        }
        // And then quick validity check:
        if (!input.startsWith('/')) {
            throw new IllegalArgumentException('Invalid input: JSON Pointer expression must start with "/": ' + '"' + input + '"');
        }
        return parseTail(input);
    }
    
    public Boolean matches() { return nextSegment == null; }
    public String getMatchingProperty() { return matchingPropertyName; }
    public Integer getMatchingIndex() { return matchingElementIndex; }
    public Boolean mayMatchProperty() { return matchingPropertyName != null; }
    public Boolean mayMatchElement() { return matchingElementIndex >= 0; }
    
    /** Returns the leaf of current JSON Pointer expression.
     *  Leaf is the last non-null segment of current JSON Pointer.
     */
    public RT_JsonPointer last() {
        RT_JsonPointer current = this;
        if (current == EMPTY) {
            return null;
        }
        RT_JsonPointer next;
        while ((next = current.nextSegment) != EMPTY) {
            current = next;
        }
        return current;
    }
    
    public RT_JsonPointer append(RT_JsonPointer tail) {
        if (this == EMPTY) {
            return tail;
        }
        if (tail == EMPTY) {
            return this;
        }
        return compile(asString.removeEnd('/') + tail.asString);
    }
    
    /** Method that may be called to see if the pointer would match property
     *  (of a JSON Object) with given name.
     */
    public Boolean matchesProperty(String name) {
        return nextSegment != null && matchingPropertyName == name;
    }
    
    public RT_JsonPointer matchProperty(String name) {
        return matchesProperty(name) ? nextSegment : null;
    }
    
    /** Method that may be called to see if the pointer would match
     *  array element (of a JSON Array) with given index.
     */
    public Boolean matchesElement(Integer index) {
        return index == matchingElementIndex && index >= 0;
    }
    
    public RT_JsonPointer matchElement(Integer index) {
        return matchesElement(index) ? nextSegment : null;
    }
    
    /** Accessor for getting a "sub-pointer", instance where current segment
     *  has been removed and pointer includes rest of segments.
     *  For matching state, will return null.
     */
    public RT_JsonPointer tail() {
        return nextSegment;
    }
    
    /** Accessor for getting a pointer instance that is identical to this
     *  instance except that the last segment has been dropped.
     *  For example, for JSON Point "/root/branch/leaf", this method would return
     *  pointer "/root/branch" (compared to #tail() that would return "/branch/leaf").
     */
    public RT_JsonPointer head() {
        RT_JsonPointer h = head;
        if (h == null) {
            if (this != EMPTY) {
                h = constructHead();
            }
            head = h;
        }
        return h;
    }
    
    public override String toString() { return asString; }
    
    public Integer hashCode() { return System.hashCode(asString); }
    
    public Boolean equals(Object o) {
        if (o === this) { return true; } // *NOPAD*
        if (o == null) { return false; }
        if (!(o instanceof RT_JsonPointer)) { return false; }
        return asString == ((RT_JsonPointer) o).asString;
    }
    
    private static Integer parseIndex(String str) {
        List<String> chars = RT_JsonUtil.explode(str);
        Integer len = str.length();
        if (len == 0 || len > 10) {
            return -1;
        }
        String c = chars.get(0);
        if (c <= '0') {
            return len == 1 && c == '0' ? 0 : -1;
        }
        if (c > '9') {
            return -1;
        }
        for (Integer i = 1; i < len; ++i) {
            c = chars.get(i);
            if (c > '9' || c < '0') {
                return -1;
            }
        }
        if (len == 10) {
            Long l = RT_JsonUtil.toLong(str);
            if (l > RT_JsonUtil.MAX_INTEGER) {
                return -1;
            }
        }
        return RT_JsonUtil.toInteger(str);
    }
    
    private static RT_JsonPointer parseTail(String input) {
        List<String> chars = RT_JsonUtil.explode(input);
        Integer len = input.length();
        
        // first char is the contextual slash, skip
        for (Integer i = 1; i < len; ) {
            String c = chars.get(i);
            if (c == '/') { // common case, got a segment
                return new RT_JsonPointer(input, input.substring(1, i), parseTail(input.substring(i)));
            }
            ++i;
            // quoting is different; offline this case
            if (c == '~' && i < len) { // possibly, quote
                return parseQuotedTail(input, i);
            }
            // otherwise, loop on
        }
        // end of the road, no escapes
        return new RT_JsonPointer(input, input.substring(1), EMPTY);
    }
    
    /** Method called to parse tail of pointer path, when a potentially
     *  escaped character has been seen.
     */
    private static RT_JsonPointer parseQuotedTail(String input, Integer i) {
        List<String> chars = RT_JsonUtil.explode(input);
        Integer len = input.length();
        String res = '';
        if (i > 2) {
            res += input.substring(1, i - 1);
        }
        res = appendEscape(res, chars.get(i++));
        while (i < len) {
            String c = chars.get(i);
            if (c == '/') { // end is nigh!
                return new RT_JsonPointer(input, res, parseTail(input.substring(i)));
            }
            ++i;
            if (c == '~' && i < len) {
                res = appendEscape(res, chars.get(i++));
                continue;
            }
            res += c;
        }
        // end of the road, last segment
        return new RT_JsonPointer(input, res, EMPTY);
    }
    
    private RT_JsonPointer constructHead() {
        // ok; find out who we are to drop
        RT_JsonPointer last = last();
        if (last == this) {
            return EMPTY;
        }
        // and from that, length of suffix to drop
        Integer suffixLength = last.asString.length();
        RT_JsonPointer next = nextSegment;
        return new RT_JsonPointer(asString.substring(0, asString.length() - suffixLength), matchingPropertyName,
                                  matchingElementIndex, next.constructHead(suffixLength, last));
    }
    
    private RT_JsonPointer constructHead(Integer suffixLength, RT_JsonPointer last) {
        if (this == last) {
            return EMPTY;
        }
        RT_JsonPointer next = nextSegment;
        String str = asString;
        return new RT_JsonPointer(str.substring(0, str.length() - suffixLength), matchingPropertyName,
                                  matchingElementIndex, next.constructHead(suffixLength, last));
    }
    
    private static String appendEscape(String input, String c) {
        String result = input;
        if (c == '0') {
            c = '~';
        }
        else if (c == '1') {
            c = '/';
        }
        else {
            result += '~';
        }
        result += c;
        return result;
    }
    
    public class IllegalArgumentException extends Exception {}
}