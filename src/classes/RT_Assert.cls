/**
 * JUnit-style assertions
 */
public class RT_Assert {

	public static final RT_Assert INSTANCE = new RT_Assert();

	@testVisible
	private Boolean noFail = false;

	public void assertTrue(Object actual) {
		System.assertEquals(true, actual);
	}

	public void assertTrue(String message, Object actual) {
		System.assertEquals(true, actual, message);
	}

	public void assertFalse(Object actual) {
		System.assertEquals(false, actual);
	}

	public void assertFalse(String message, Object actual) {
		System.assertEquals(false, actual, message);
	}

	public void assertEquals(Object expected, Object actual) {
		System.assertEquals(expected, actual);
	}

	public void assertEquals(String message, Object expected, Object actual) {
		System.assertEquals(expected, actual, message);
	}

	public void assertNotEquals(Object expected, Object actual) {
		System.assertNotEquals(expected, actual);
	}

	public void assertNotEquals(String message, Object expected, Object actual) {
		System.assertNotEquals(expected, actual, message);
	}

	public void assertNull(Object actual) {
		System.assertEquals(null, actual);
	}

	public void assertNull(String message, Object actual) {
		System.assertEquals(null, actual, message);
	}

	public void assertNotNull(Object actual) {
		System.assertNotEquals(null, actual);
	}

	public void assertNotNull(String message, Object actual) {
		System.assertNotEquals(null, actual, message);
	}

	public void assertSame(Object expected, Object actual) {
		assertSame('Expected: ' + expected + ', Actual: ' + actual, expected, actual); // *NOPAD*
	}

	public void assertSame(String message, Object expected, Object actual) {
		System.assert(expected === actual, message); // *NOPAD*
	}

	public void assertNotSame(Object expected, Object actual) {
		System.assert(expected !== actual); // *NOPAD*
	}

	public void assertNotSame(String message, Object expected, Object actual) {
		System.assert(expected !== actual, message); // *NOPAD*
	}

	public void assertBlank(String actual) {
		assertBlank('Expected blank string, got: "' + actual + '"', actual);
	}

	public void assertBlank(String message, String actual) {
		System.assert(String.isBlank(actual), message);
	}

	public void assertNotBlank(String actual) {
		assertNotBlank('Expected non-blank string, got: "' + actual + '"', actual);
	}

	public void assertNotBlank(String message, String actual) {
		System.assert(String.isNotBlank(actual), message);
	}

	public void fail() {
		System.assert(noFail ? true : false);
	}

	public void fail(String message) {
		System.assert(noFail ? true : false, message);
	}
}