public class RT_JsonUtil {
	
	public static final Map<String, SObjectType> GD;
	static {
		GD = Schema.getGlobalDescribe();
	}

	public static final Set<DisplayType> STRING_TYPES, INTEGER_TYPES, ID_TYPES,
	       DOUBLE_TYPES, DATETIME_TYPES, DATE_TYPES, BOOLEAN_TYPES;
	       
	static {
		STRING_TYPES = new Set<DisplayType> {
			DisplayType.BASE64,
			DisplayType.EMAIL,
			DisplayType.MULTIPICKLIST,
			DisplayType.PHONE,
			DisplayType.PICKLIST,
			DisplayType.STRING,
			DisplayType.TEXTAREA,
			DisplayType.URL
		};
		INTEGER_TYPES = new Set<DisplayType> {
			DisplayType.INTEGER
		};
		ID_TYPES = new Set<DisplayType> {
			DisplayType.ID,
			DisplayType.REFERENCE
		};
		DOUBLE_TYPES = new Set<DisplayType> {
			DisplayType.CURRENCY,
			DisplayType.DOUBLE,
			DisplayType.PERCENT
		};
		DATETIME_TYPES = new Set<DisplayType> {
			DisplayType.DATETIME
		};
		DATE_TYPES = new Set<DisplayType> {
			DisplayType.DATE
		};
		BOOLEAN_TYPES = new Set<DisplayType> {
			DisplayType.BOOLEAN,
			DisplayType.COMBOBOX
		};
	}
	
	public static final Integer MIN_INTEGER, MAX_INTEGER, HASH_PRIME;
	static {
		MAX_INTEGER = Math.pow(2, 31).intValue();
		MIN_INTEGER = MAX_INTEGER + 1;
		HASH_PRIME = 31;
	}
	
	public static Boolean inIntRange(Long l) {
		return l >= MIN_INTEGER && l <= MAX_INTEGER;
	}
	
	static Map<SObjectType, Map<String, DescribeFieldResult>> dfrBySObjType;
	static {
		dfrBySObjType = new Map<SObjectType, Map<String, DescribeFieldResult>>();
	}
	
	static Map<SObjectType, Map<String, ChildRelationship>> relCache;
	static {
		relCache = new Map<SObjectType, Map<String, ChildRelationship>>();
	}
	
	/**
	 * Safely generate a hashCode for a given object. If null, result is zero.
	 */
	public static Integer hashCode(Object obj) {
		return obj == null ? 0 : System.hashCode(obj);
	}

	public static Integer hashCode(Object obj, Integer result) {
		return HASH_PRIME * result + hashCode(obj);
	}
	
	/**
	 * Check if object is not a Decimal, Double, Integer, or Long.
	 */
	public static Boolean isNaN(Object o) {
		return o == null || !(o instanceof Decimal || o instanceof Double || o instanceof Integer || o instanceof Long);
	}
	
	public static Double toDouble(Object obj, Double defaultValue) {
		Double result = defaultValue;
		if (obj != null && obj instanceof Boolean) {
			obj = (Boolean) obj ? 1 : 0;
		}
		if (!isNaN(obj) || obj instanceof String) {
			try {
				Double d = Double.valueOf(obj);
				result = d;
			}
			catch (Exception e) {}
		}
		return result;
	}
	
	public static Double toDouble(Object obj) {
		return toDouble(obj, 0);
	}
	
	public static Decimal toDecimal(Object obj, Decimal defaultValue) {
		return toDouble(obj, Double.valueOf(defaultValue));
	}
	
	public static Decimal toDecimal(Object obj) {
		return toDouble(obj, 0);
	}
	
	public static Integer toInteger(Object obj, Integer defaultValue) {
		return Integer.valueOf(toDouble(obj, Double.valueOf(defaultValue)));
	}
	
	public static Integer toInteger(Object obj) {
		return Integer.valueOf(toDouble(obj, 0));
	}
	
	public static Long toLong(Object obj, Long defaultValue) {
		return (Long) toDouble(obj, Double.valueOf(defaultValue));
	}
	
	public static Long toLong(Object obj) {
		return (Long) toDouble(obj, 0);
	}

	public static Boolean toBoolean(Object o) {
		return toBoolean(o, null);
	}
	
	public static Boolean toBoolean(Object o, Boolean defaultValue) {
		try {
			return Boolean.valueOf(o);
		}
		catch (Exception e) {
			return defaultValue;
		}
	}
	
	public static Boolean isDate(Object o) {
		return o != null && (o instanceof Date || o instanceof DateTime);
	}
	
	public static Date toDate(Object obj) {
		Date result;
		if (obj != null) {
			if (obj instanceof Date) {
				result = (Date) obj;
			}
			else if (obj instanceof String && isValidDate(obj)) {
				try {
					result = Date.parse((String) obj);
				}
				catch (Exception e) {
					try {
						result = (Date) JSON.deserialize((String) obj, Date.class);
					}
					catch (Exception e2) {
						result = null;
					}
				}
			}
			else {
				DateTime dt = toDateTime(obj);
				if (dt != null) {
					result = dt.date();
				}
			}
		}
		return result;
	}
	
	public static DateTime toDateTime(Object obj) {
		DateTime result;
		if (obj != null) {
			if (obj instanceof Date) {
				Date d = (Date) obj;
				result = DateTime.newInstance(d.year(), d.month(), d.day());
			}
			else if (obj instanceof DateTime) {
				result = (DateTime) obj;
			}
			else if (!isNaN(obj)) {
				result = DateTime.valueOf(obj);
			}
			else if (obj instanceof String && isValidDateTime(obj)) {
				try {
					result = DateTime.parse((String) obj);
				}
				catch (Exception e) {
					try {
						result = (DateTime) JSON.deserialize((String) obj, DateTime.class);
					}
					catch (Exception e2) {
						result = null;
					}
				}
			}
		}
		return result;
	}
	
	public static Boolean isValidDate(Object obj) {
		Boolean result;
		if (obj == null || !isNaN(obj)) {
			result = false;
		}
		else if (isDate(obj)) {
			result = true;
		}
		else {
			try {
				result = obj instanceof String && Date.parse((String) obj) != null;
			}
			catch (Exception e) {
				try {
					result = JSON.deserialize((String) obj, Date.class) != null;
				}
				catch (Exception e2) {
					result = false;
				}
			}
		}
		return result;
	}
	
	public static Boolean isValidDateTime(Object obj) {
		Boolean result;
		if (obj == null) {
			result = false;
		}
		else if (isDate(obj)) {
			result = true;
		}
		else {
			try {
				DateTime dt;
				if (!isNaN(obj)) {
					dt = DateTime.valueOf(obj);
				}
				else if (obj instanceof String) {
					try {
						dt = DateTime.valueOf(String.valueOf(obj));
					}
					catch (Exception e) {
						try {
							dt = (DateTime) JSON.deserialize((String) obj, DateTime.class);
						}
						catch (Exception e2) {
							dt = null;
						}
					}
				}
				result = dt != null;
			}
			catch (Exception e) {
				result = false;
			}
		}
		return result;
	}
	
	/**
	 * Convert objects to strings using String.valueOf on each element.
	 */
	public static List<String> asStrings(List<Object> objs) {
		List<String> result;
		if (objs != null) {
			result = new List<String>();
			for (Object o : objs) {
				result.add(String.valueOf(o));
			}
		}
		return result;
	}
	
	/**
	 * Explode a string into a list of characters
	 * @param str - the String to explode
	 * @return list of String's characters
	 */
	public static List<String> explode(String str) {
		List<String> result;
		if (str != null) {
			result = str.split('');
			result.remove(0);
		}
		return result;
	}
	
	public static String join(Set<String> strings, String del) {
		if (del == null) {
			del = '';
		}
		return String.join(new List<String>(strings), del);
	}
	
	public static Map<String, Object> objectToMap(Object obj) {
		Map<String, Object> results;
		try {
			String jsonString = JSON.serialize(obj);
			Object deserialized = JSON.deserializeUntyped(jsonString);
			results = (Map<String, Object>) deserialized;
		}
		catch (Exception e) {
			// obj is null, has no members, or isn't an instance of a custom class
			results = new Map<String, Object>();
		}
		return results;
	}
	
	/**
	 * Checks the schema public describe for existence
	 * of the given type (case-insensitive).
	 */
	public static Boolean sObjectTypeExists(String type) {
		return GD.containsKey(type);
	}

	public static SObjectType getSObjectType(String name) {
		return GD.get(name);
	}
	
	/**
	 * Provides a mapping of SObjectFields, keyed by their lowercased names, that
	 * exist on the given SObjectType.
	 */
	public static Map<String, SObjectField> sObjectFieldMap(SObjectType stype) {
		if (stype != null) {
			return stype.getDescribe().fields.getMap();
		}
		return new Map<String, SObjectField>();
	}
	
	public static SObject unsetFields(SObject record, Set<SObjectField> fieldsToUnset) {
		SObjectType stype = record.getSObjectType();
		Set<String> recordFields = objectToMap(record).keySet();
		recordFields.remove('attributes');
		List<String> fieldNamesToUnset = asStrings(new List<SObjectField>(fieldsToUnset));
		for (SObjectField f : fieldsToUnset) {
			String relName = f.getDescribe().getRelationshipName();
			if (relName != null) {
				fieldNamesToUnset.add(relName);
			}
		}
		if (recordFields.removeAll(fieldNamesToUnset)) {
			SObject newRecord = stype.newSObject();
			for (String f : recordFields) {
				newRecord.put(f, record.get(f));
			}
			record = newRecord;
		}
		return record;
	}
	
	public static Map<String, DescribeFieldResult> getDescribeFieldResults(SObjectType stype) {
		Map<String, DescribeFieldResult> dfrMap;
		if (stype != null) {
			dfrMap = dfrBySObjType.get(stype);
			if (!dfrBySObjType.containsKey(stype)) {
				dfrBySObjType.put(stype, dfrMap = new Map<String, DescribeFieldResult>());
			}
			if (dfrMap.isEmpty()) {
				Map<String, SObjectField> fieldMap = sObjectFieldMap(stype);
				for (String fieldName : fieldMap.keySet()) {
					DescribeFieldResult dfr = fieldMap.get(fieldName).getDescribe();
					dfrMap.put(fieldName.toLowerCase(), dfr);
				}
			}
		}
		return dfrMap;
	}
	
	public static DisplayType getDisplayType(SObjectField field) {
		DisplayType dt;
		if (field != null) {
			dt = field.getDescribe().getType();
		}
		return dt;
	}
	
	public static Map<String, ChildRelationship> getChildRelationships(SObjectType type) {
		Map<String, ChildRelationship> rels;
		if (type != null && (rels = relCache.get(type)) == null) {
			relCache.put(type, rels = new Map<String, ChildRelationship>());
			for (ChildRelationship rel : type.getDescribe().getChildRelationships()) {
				String relName = rel.getRelationshipName();
				if (relName != null) {
					rels.put(relName.toLowerCase(), rel);
				}
			}
		}
		return rels == null ? new Map<String, ChildRelationship>() : rels;
	}
}