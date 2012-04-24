
#import <Foundation/Foundation.h>

@class DDXMLDocument;

/**
 * Welcome to KissXML.
 * 
 * The project page has documentation if you have questions.
 * https://github.com/robbiehanson/KissXML
 * 
 * If you're new to the project you may wish to read the "Getting Started" wiki.
 * https://github.com/robbiehanson/KissXML/wiki/GettingStarted
 * 
 * KissXML provides a drop-in replacement for Apple's NSXML class cluster.
 * The goal is to get the exact same behavior as the NSXML classes.
 * 
 * For API Reference, see Apple's excellent documentation,
 * either via Xcode's Mac OS X documentation, or via the web:
 * 
 * https://github.com/robbiehanson/KissXML/wiki/Reference
**/

typedef NSUInteger DDXMLNodeKind;

extern DDXMLNodeKind DDXMLInvalidKind;
extern DDXMLNodeKind DDXMLDocumentKind;
extern DDXMLNodeKind DDXMLElementKind;
extern DDXMLNodeKind DDXMLAttributeKind;
extern DDXMLNodeKind DDXMLNamespaceKind;
extern DDXMLNodeKind DDXMLProcessingInstructionKind;
extern DDXMLNodeKind DDXMLCommentKind;
extern DDXMLNodeKind DDXMLTextKind;
extern DDXMLNodeKind DDXMLDTDKind;
extern DDXMLNodeKind DDXMLEntityDeclarationKind;
extern DDXMLNodeKind DDXMLAttributeDeclarationKind;
extern DDXMLNodeKind DDXMLElementDeclarationKind;
extern DDXMLNodeKind DDXMLNotationDeclarationKind;

enum {
	DDXMLNodeOptionsNone            = 0,
	DDXMLNodeExpandEmptyElement     = 1 << 1,
	DDXMLNodeCompactEmptyElement    = 1 << 2,
	DDXMLNodePrettyPrint            = 1 << 17,
};


//extern struct _xmlKind;


@interface DDXMLNode : NSObject <NSCopying>

//- (id)initWithKind:(DDXMLNodeKind)kind;

//- (id)initWithKind:(DDXMLNodeKind)kind options:(NSUInteger)options;

//+ (id)document;

//+ (id)documentWithRootElement:(DDXMLElement *)element;

+ (id)elementWithName:(NSString *)name;

+ (id)elementWithName:(NSString *)name URI:(NSString *)URI;

+ (id)elementWithName:(NSString *)name stringValue:(NSString *)string;

+ (id)elementWithName:(NSString *)name children:(NSArray *)children attributes:(NSArray *)attributes;

+ (id)attributeWithName:(NSString *)name stringValue:(NSString *)stringValue;

+ (id)attributeWithName:(NSString *)name URI:(NSString *)URI stringValue:(NSString *)stringValue;

+ (id)namespaceWithName:(NSString *)name stringValue:(NSString *)stringValue;

+ (id)processingInstructionWithName:(NSString *)name stringValue:(NSString *)stringValue;

+ (id)commentWithStringValue:(NSString *)stringValue;

+ (id)textWithStringValue:(NSString *)stringValue;

//+ (id)DTDNodeWithXMLString:(NSString *)string;

#pragma mark --- Properties ---

- (DDXMLNodeKind)kind;

- (void)setName:(NSString *)name;
- (NSString *)name;

//- (void)setObjectValue:(id)value;
//- (id)objectValue;

- (void)setStringValue:(NSString *)string;
//- (void)setStringValue:(NSString *)string resolvingEntities:(BOOL)resolve;
- (NSString *)stringValue;

#pragma mark --- Tree Navigation ---

- (NSUInteger)index;

- (NSUInteger)level;

- (DDXMLDocument *)rootDocument;

- (DDXMLNode *)parent;
- (NSUInteger)childCount;
- (NSArray *)children;
- (DDXMLNode *)childAtIndex:(NSUInteger)idx;

- (DDXMLNode *)previousSibling;
- (DDXMLNode *)nextSibling;

- (DDXMLNode *)previousNode;
- (DDXMLNode *)nextNode;

- (void)detach;

- (NSString *)XPath;

#pragma mark --- QNames ---

- (NSString *)localName;
- (NSString *)prefix;

- (void)setURI:(NSString *)URI;
- (NSString *)URI;

+ (NSString *)localNameForName:(NSString *)name;
+ (NSString *)prefixForName:(NSString *)name;
//+ (DDXMLNode *)predefinedNamespaceForPrefix:(NSString *)name;

#pragma mark --- Output ---

- (NSString *)description;
- (NSString *)XMLString;
- (NSString *)XMLStringWithOptions:(NSUInteger)options;
//- (NSString *)canonicalXMLStringPreservingComments:(BOOL)comments;

#pragma mark --- XPath/XQuery ---

/*!
	\brief
	Invokes `nodesForXPath:namespaceMap:error:` with `NSXMLNode` like namespace behaviour
 */
- (NSArray *)nodesForXPath:(NSString *)XPath error:(NSError **)error;

/*!
	\brief
	Register namespace prefix to URI tuples in the XPath parser.
	
	\param namespaceMap
	Pass `nil` to mimic the `NSXMLNode` `nodesForXPath:error:` behaviour.
 */
- (NSArray *)nodesForXPath:(NSString *)XPath namespaceMap:(NSDictionary *)namespaceMap error:(NSError **)errorRef;

//- (NSArray *)objectsForXQuery:(NSString *)XQuery constants:(NSDictionary *)constants error:(NSError **)error;
//- (NSArray *)objectsForXQuery:(NSString *)XQuery error:(NSError **)error;

@end
