@isTest class RT_JsonPointerTest {
    
    static final RT_Assert Assert = RT_Assert.INSTANCE;

    @isTest static void testSimplePath() {
        String input = '/Image/15/name';
        
        RT_JsonPointer ptr = RT_JsonPointer.compile(input);
        Assert.assertFalse(ptr.matches());
        Assert.assertEquals(-1, ptr.getMatchingIndex());
        Assert.assertEquals('Image', ptr.getMatchingProperty());
        Assert.assertEquals('/Image/15', ptr.head().toString());
        Assert.assertEquals(input, ptr.toString());
        
        ptr = ptr.tail();
        Assert.assertNotNull(ptr);
        Assert.assertFalse(ptr.matches());
        Assert.assertEquals(15, ptr.getMatchingIndex());
        Assert.assertEquals('15', ptr.getMatchingProperty());
        Assert.assertEquals('/15/name', ptr.toString());
        Assert.assertEquals('/15', ptr.head().toString());
        
        Assert.assertEquals('', ptr.head().head().toString());
        Assert.assertNull(ptr.head().head().head());
        
        ptr = ptr.tail();
        Assert.assertNotNull(ptr);
        Assert.assertFalse(ptr.matches());
        Assert.assertEquals(-1, ptr.getMatchingIndex());
        Assert.assertEquals('name', ptr.getMatchingProperty());
        Assert.assertEquals('/name', ptr.toString());
        Assert.assertEquals('', ptr.head().toString());
        Assert.assertSame(RT_JsonPointer.EMPTY, ptr.head());
        
        // done!
        ptr = ptr.tail();
        Assert.assertTrue(ptr.matches());
        Assert.assertNull(ptr.tail());
        Assert.assertNull(ptr.head());
        Assert.assertEquals('', ptr.getMatchingProperty());
        Assert.assertEquals(-1, ptr.getMatchingIndex());
    }
    
    @isTest static void testSimplePathLonger() {
        String input = '/a/b/c/d/e/f/0';
        RT_JsonPointer ptr = RT_JsonPointer.compile(input);
        Assert.assertFalse(ptr.matches());
        Assert.assertEquals(-1, ptr.getMatchingIndex());
        Assert.assertEquals('a', ptr.getMatchingProperty());
        Assert.assertEquals('/a/b/c/d/e/f', ptr.head().toString());
        Assert.assertEquals('/b/c/d/e/f/0', ptr.tail().toString());
        Assert.assertTrue(ptr.last().mayMatchElement());
        Assert.assertEquals('/0', ptr.last().toString());
        Assert.assertEquals(input, ptr.toString());
    }
    
    @isTest static void testWonkyNumber173() {
        RT_JsonPointer ptr = RT_JsonPointer.compile('/1e0');
        Assert.assertFalse(ptr.matches());
    }
    
    // do not allow leading zeroes
    @isTest static void testIZeroIndex() {
        RT_JsonPointer ptr = RT_JsonPointer.compile('/0');
        Assert.assertEquals(0, ptr.getMatchingIndex());
        ptr = RT_JsonPointer.compile('/00');
        Assert.assertEquals(-1, ptr.getMatchingIndex());
    }
    
    @isTest static void testLast() {
        String input = '/Image/15/name';
        
        RT_JsonPointer ptr = RT_JsonPointer.compile(input);
        RT_JsonPointer leaf = ptr.last();
        
        Assert.assertEquals('name', leaf.getMatchingProperty());
    }
    
    @isTest static void testEmpty() {
        // note: this is acceptable, to match property in '{'':3}', for example
        // and NOT same as what empty point, '', is.
        RT_JsonPointer ptr = RT_JsonPointer.compile('/');
        Assert.assertNotNull(ptr);
        Assert.assertNotSame(RT_JsonPointer.EMPTY, ptr);
        Assert.assertEquals('/', ptr.toString());
    }
    
    @isTest static void testAppend() {
        String input = '/Image/15/name';
        String append = '/extension';
        
        RT_JsonPointer ptr = RT_JsonPointer.compile(input);
        RT_JsonPointer apd = RT_JsonPointer.compile(append);
        
        RT_JsonPointer appended = ptr.append(apd);
        
        Assert.assertEquals('extension', appended.last().getMatchingProperty());
    }
    
    @isTest static void testAppendWithFinalSlash() {
        String input = '/Image/15/name/';
        String append = '/extension';
        
        RT_JsonPointer ptr = RT_JsonPointer.compile(input);
        RT_JsonPointer apd = RT_JsonPointer.compile(append);
        
        RT_JsonPointer appended = ptr.append(apd);
        
        Assert.assertEquals('extension', appended.last().getMatchingProperty());
    }
    
    @isTest static void testQuotedPath() {
        String input = '/w~1out/til~0de/a~1b';
        
        RT_JsonPointer ptr = RT_JsonPointer.compile(input);
        Assert.assertFalse(ptr.matches());
        Assert.assertEquals(-1, ptr.getMatchingIndex());
        Assert.assertEquals('w/out', ptr.getMatchingProperty());
        Assert.assertEquals('/w~1out/til~0de', ptr.head().toString());
        Assert.assertEquals(input, ptr.toString());
        
        ptr = ptr.tail();
        Assert.assertNotNull(ptr);
        Assert.assertFalse(ptr.matches());
        Assert.assertEquals(-1, ptr.getMatchingIndex());
        Assert.assertTrue(ptr.mayMatchProperty());
        Assert.assertEquals('til~de', ptr.getMatchingProperty());
        Assert.assertEquals('/til~0de', ptr.head().toString());
        Assert.assertEquals('/til~0de/a~1b', ptr.toString());
        
        ptr = ptr.tail();
        Assert.assertNotNull(ptr);
        Assert.assertFalse(ptr.matches());
        Assert.assertEquals(-1, ptr.getMatchingIndex());
        Assert.assertEquals('a/b', ptr.getMatchingProperty());
        Assert.assertEquals('/a~1b', ptr.toString());
        Assert.assertEquals('', ptr.head().toString());
        
        // done!
        ptr = ptr.tail();
        Assert.assertTrue(ptr.matches());
        Assert.assertNull(ptr.tail());
    }
    
    @isTest static void testLongNumbers() {
        Long longId = RT_JsonUtil.MAX_INTEGER + 1L;
        
        String input = '/User/' + longId;
        
        RT_JsonPointer ptr = RT_JsonPointer.compile(input);
        Assert.assertEquals('User', ptr.getMatchingProperty());
        Assert.assertEquals(input, ptr.toString());
        
        ptr = ptr.tail();
        Assert.assertNotNull(ptr);
        Assert.assertFalse(ptr.matches());
        Assert.assertEquals(-1, ptr.getMatchingIndex());
        Assert.assertEquals(String.valueOf(longId), ptr.getMatchingProperty());
        
        // done!
        ptr = ptr.tail();
        Assert.assertTrue(ptr.matches());
        Assert.assertNull(ptr.tail());
    }

    @isTest static void testMatch() {
        String input = '/Image/15/name';
        
        RT_JsonPointer ptr = RT_JsonPointer.compile(input);
        Assert.assertTrue(ptr.matchProperty('Image').matchElement(15).matchesProperty('name'));
    }

    @isTest static void testInvalidInput() {
        try {
            RT_JsonPointer.compile('bad/input');
            Assert.assertTrue(false);
        }
        catch (Exception e) {
        }
    }
}