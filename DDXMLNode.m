
#import "DDXMLNode.h"
#import "DDXMLNode+Private.h"

#import <libxml/xpath.h>
#import <libxml/xpathInternals.h>

#import "DDXMLAttributeNode.h"
#import "DDXMLNamespaceNode.h"
#import "DDXMLInvalidNode.h"

#import "DDXMLElement.h"
#import "DDXMLElement+Private.h"

#import "DDXMLDocument.h"
#import "DDXMLDocument+Private.h"

#import "KissXML+Private.h"
#import "KissXML-Constants.h"

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


DDXMLNodeKind DDXMLInvalidKind = 0;
DDXMLNodeKind DDXMLDocumentKind = XML_DOCUMENT_NODE;
DDXMLNodeKind DDXMLElementKind = XML_ELEMENT_NODE;
DDXMLNodeKind DDXMLAttributeKind = XML_ATTRIBUTE_NODE;
DDXMLNodeKind DDXMLNamespaceKind = XML_NAMESPACE_DECL;
DDXMLNodeKind DDXMLProcessingInstructionKind = XML_PI_NODE;
DDXMLNodeKind DDXMLCommentKind = XML_COMMENT_NODE;
DDXMLNodeKind DDXMLTextKind = XML_TEXT_NODE;
DDXMLNodeKind DDXMLDTDKind = XML_DTD_NODE;
DDXMLNodeKind DDXMLEntityDeclarationKind = XML_ENTITY_DECL;
DDXMLNodeKind DDXMLAttributeDeclarationKind = XML_ATTRIBUTE_DECL;
DDXMLNodeKind DDXMLElementDeclarationKind = XML_ELEMENT_DECL;
DDXMLNodeKind DDXMLNotationDeclarationKind = XML_NOTATION_NODE;

#if DDXML_DEBUG_MEMORY_ISSUES

#error these symbols need to be namespaced more appropriately before use again

static CFMutableDictionaryRef zombieTracker;
static dispatch_queue_t zombieQueue;

static void RecursiveMarkZombiesFromNode(xmlNodePtr node);
static void RecursiveMarkZombiesFromDoc(xmlDocPtr doc);

static void MarkZombies(void *xmlPtr);
static void MarkBirth(void *xmlPtr, DDXMLNode *wrapper);
static void MarkDeath(void *xmlPtr, DDXMLNode *wrapper);

#endif /* DDXML_DEBUG_MEMORY_ISSUES */


@implementation DDXMLNode

/**
 * From Apple's Documentation:
 * 
 * The runtime sends initialize to each class in a program exactly one time just before the class,
 * or any class that inherits from it, is sent its first message from within the program. (Thus the method may
 * never be invoked if the class is not used.) The runtime sends the initialize message to classes
 * in a thread-safe manner. Superclasses receive this message before their subclasses.
 * 
 * The method may also be called directly (assumably by accident), hence the safety mechanism.
**/
+ (void)initialize
{
	[super initialize];
	if (self != [DDXMLNode class]) return;
	
	// Redirect error output to our own function (don't clog up the console)
	DDXMLCheckAndSetErrorHandlerForCurrentThread();
	
	// Tell libxml not to keep ignorable whitespace (such as node indentation, formatting, etc).
	// NSXML ignores such whitespace.
	// This also has the added benefit of taking up less RAM when parsing formatted XML documents.
	xmlKeepBlanksDefault(0);
	
#if DDXML_DEBUG_MEMORY_ISSUES
	zombieTracker = CFDictionaryCreateMutable(NULL, 0, NULL, &kCFTypeDictionaryValueCallBacks);
	zombieQueue = dispatch_queue_create("DDXMLZombieQueue", NULL);
#endif /* DDXML_DEBUG_MEMORY_ISSUES */
}

+ (id)elementWithName:(NSString *)name
{
	return [[[DDXMLElement alloc] initWithName:name] autorelease];
}

+ (id)elementWithName:(NSString *)name stringValue:(NSString *)string
{
	return [[[DDXMLElement alloc] initWithName:name stringValue:string] autorelease];
}

+ (id)elementWithName:(NSString *)name children:(NSArray *)children attributes:(NSArray *)attributes
{
	DDXMLElement *result = [[[DDXMLElement alloc] initWithName:name] autorelease];
	[result setChildren:children];
	[result setAttributes:attributes];
	
	return result;
}

+ (id)elementWithName:(NSString *)name URI:(NSString *)URI
{
	return [[[DDXMLElement alloc] initWithName:name URI:URI] autorelease];
}

+ (id)attributeWithName:(NSString *)name stringValue:(NSString *)stringValue
{
	return [self attributeWithName:name URI:nil stringValue:stringValue];
}

+ (id)attributeWithName:(NSString *)name URI:(NSString *)URI stringValue:(NSString *)stringValue
{
	DDXMLCheckAndSetErrorHandlerForCurrentThread();
	
	xmlAttrPtr attr = xmlNewProp(NULL, (const xmlChar *)[name UTF8String], (const xmlChar *)[stringValue UTF8String]);
	
	if (attr == NULL) return nil;
	
	DDXMLAttributeNode *result = [[[DDXMLAttributeNode alloc] initWithAttrPrimitive:attr owner:nil] autorelease];
	if (URI != nil) {
		[result setURI:URI];
	}
	
	return result;
}

+ (id)namespaceWithName:(NSString *)name stringValue:(NSString *)stringValue
{
	DDXMLCheckAndSetErrorHandlerForCurrentThread();
	
	// If the user passes a nil or empty string name, they are trying to create a default namespace
	const xmlChar *xmlName = [name length] > 0 ? (const xmlChar *)[name UTF8String] : NULL;
	
	xmlNsPtr ns = xmlNewNs(NULL, (const xmlChar *)[stringValue UTF8String], xmlName);
	
	if (ns == NULL) return nil;
	
	return [[[DDXMLNamespaceNode alloc] initWithNsPrimitive:ns nsParent:NULL owner:nil] autorelease];
}

+ (id)processingInstructionWithName:(NSString *)name stringValue:(NSString *)stringValue
{
	DDXMLCheckAndSetErrorHandlerForCurrentThread();
	
	xmlNodePtr procInst = xmlNewPI((const xmlChar *)[name UTF8String], (const xmlChar *)[stringValue UTF8String]);
	
	if (procInst == NULL) return nil;
	
	return [[[DDXMLNode alloc] initWithPrimitive:(xmlKindPtr)procInst owner:nil] autorelease];
}

+ (id)commentWithStringValue:(NSString *)stringValue
{
	DDXMLCheckAndSetErrorHandlerForCurrentThread();
	
	xmlNodePtr comment = xmlNewComment((const xmlChar *)[stringValue UTF8String]);
	
	if (comment == NULL) return nil;
	
	return [[[DDXMLNode alloc] initWithPrimitive:(xmlKindPtr)comment owner:nil] autorelease];
}

+ (id)textWithStringValue:(NSString *)stringValue
{
	DDXMLCheckAndSetErrorHandlerForCurrentThread();
	
	xmlNodePtr text = xmlNewText((const xmlChar *)[stringValue UTF8String]);
	
	if (text == NULL) return nil;
	
	return [[[DDXMLNode alloc] initWithPrimitive:(xmlKindPtr)text owner:nil] autorelease];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Init, Dealloc
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

+ (id)nodeWithUnknownPrimitive:(xmlKindPtr)kindPtr owner:(DDXMLNode *)owner
{
	if (kindPtr->type == XML_DOCUMENT_NODE)
	{
		return [DDXMLDocument nodeWithDocPrimitive:(xmlDocPtr)kindPtr owner:owner];
	}
	else if (kindPtr->type == XML_ELEMENT_NODE)
	{
		return [DDXMLElement nodeWithElementPrimitive:(xmlNodePtr)kindPtr owner:owner];
	}
	else if (kindPtr->type == XML_NAMESPACE_DECL)
	{
		// Todo: This may be a problem...
		
		return [DDXMLNamespaceNode nodeWithNsPrimitive:(xmlNsPtr)kindPtr nsParent:NULL owner:owner];
	}
	else if (kindPtr->type == XML_ATTRIBUTE_NODE)
	{
		return [DDXMLAttributeNode nodeWithAttrPrimitive:(xmlAttrPtr)kindPtr owner:owner];
	}
	else
	{
		return [DDXMLNode nodeWithPrimitive:kindPtr owner:owner];
	}
}

/**
 * Returns a DDXML wrapper object for the given primitive node.
 * The given node MUST be non-NULL and of the proper type.
**/
+ (id)nodeWithPrimitive:(xmlKindPtr)kindPtr owner:(DDXMLNode *)owner
{
	return [[[DDXMLNode alloc] initWithPrimitive:kindPtr owner:owner] autorelease];
}

/**
 * Returns a DDXML wrapper object for the given primitive node.
 * The given node MUST be non-NULL and of the proper type.
**/
- (id)initWithPrimitive:(xmlKindPtr)kindPtr owner:(DDXMLNode *)inOwner
{
	if ((self = [super init]))
	{
		genericPtr = kindPtr;
		owner = [inOwner retain];
		
	#if DDXML_DEBUG_MEMORY_ISSUES
		MarkBirth(genericPtr, self);
	#endif
	}
	return self;
}

/**
 * This method shouldn't be used.
 * To maintain compatibility with Apple, we return an invalid node.
**/
- (id)init
{
	self = [super init];
	
	if ([self isKindOfClass:[DDXMLInvalidNode class]])
	{
		return self;
	}
	else
	{
		[self release];
		return [[DDXMLInvalidNode alloc] init];
	}
}

- (void)dealloc
{
	DDXMLCheckAndSetErrorHandlerForCurrentThread();
	
#if DDXML_DEBUG_MEMORY_ISSUES
	MarkDeath(genericPtr, self);
#endif
	
	// We also check if genericPtr is NULL.
	// This may be the case if, e.g., DDXMLElement calls [self release] from it's init method.
	
	if ((owner == nil) && (genericPtr != NULL))
	{
		if (IsXmlNsPtr(genericPtr))
		{
		#if DDXML_DEBUG_MEMORY_ISSUES
			MarkZombies(genericPtr);
		#endif
			xmlFreeNs((xmlNsPtr)genericPtr);
		}
		else if (IsXmlAttrPtr(genericPtr))
		{
		#if DDXML_DEBUG_MEMORY_ISSUES
			MarkZombies(genericPtr);
		#endif
			xmlFreeProp((xmlAttrPtr)genericPtr);
		}
		else if (IsXmlDtdPtr(genericPtr))
		{
		#if DDXML_DEBUG_MEMORY_ISSUES
			MarkZombies(genericPtr);
		#endif
			xmlFreeDtd((xmlDtdPtr)genericPtr);
		}
		else if (IsXmlDocPtr(genericPtr))
		{
			xmlDocPtr doc = (xmlDocPtr)genericPtr;
			
		#if DDXML_DEBUG_MEMORY_ISSUES
			RecursiveMarkZombiesFromDoc(doc);
		#endif
			xmlFreeDoc(doc);
		}
		else if (IsXmlNodePtr(genericPtr))
		{
			xmlNodePtr node = (xmlNodePtr)genericPtr;
			
		#if DDXML_DEBUG_MEMORY_ISSUES
			RecursiveMarkZombiesFromNode(node);
		#endif
			xmlFreeNode(node);
		}
		else
		{
			NSAssert1(NO, @"Cannot free unknown node type: %i", genericPtr->type);
		}
	}
	
	[owner release];
	[super dealloc];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Copying
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (id)copyWithZone:(NSZone *)zone
{
	DDXMLCheckAndSetErrorHandlerForCurrentThread();
	
	DDXMLNotZombieAssert();
	
	if (IsXmlDocPtr(genericPtr))
	{
		xmlDocPtr copyDocPtr = xmlCopyDoc((xmlDocPtr)genericPtr, 1);
		
		if (copyDocPtr == NULL) return nil;
		
		return [[DDXMLDocument alloc] initWithDocPrimitive:copyDocPtr owner:nil];
	}
	
	if (IsXmlNodePtr(genericPtr))
	{
		xmlNodePtr copyNodePtr = xmlCopyNode((xmlNodePtr)genericPtr, 1);
		
		if (copyNodePtr == NULL) return nil;
		
		if ([self isKindOfClass:[DDXMLElement class]])
			return [[DDXMLElement alloc] initWithElementPrimitive:copyNodePtr owner:nil];
		else
			return [[DDXMLNode alloc] initWithPrimitive:(xmlKindPtr)copyNodePtr owner:nil];
	}
	
	if (IsXmlAttrPtr(genericPtr))
	{
		xmlAttrPtr copyAttrPtr = xmlCopyProp(NULL, (xmlAttrPtr)genericPtr);
		
		if (copyAttrPtr == NULL) return nil;
		
		return [[DDXMLAttributeNode alloc] initWithAttrPrimitive:copyAttrPtr owner:nil];
	}
	
	if (IsXmlNsPtr(genericPtr))
	{
		xmlNsPtr copyNsPtr = xmlCopyNamespace((xmlNsPtr)genericPtr);
		
		if (copyNsPtr == NULL) return nil;
		
		return [[DDXMLNamespaceNode alloc] initWithNsPrimitive:copyNsPtr nsParent:NULL owner:nil];
	}
	
	if (IsXmlDtdPtr(genericPtr))
	{
		xmlDtdPtr copyDtdPtr = xmlCopyDtd((xmlDtdPtr)genericPtr);
		
		if (copyDtdPtr == NULL) return nil;
		
		return [[DDXMLNode alloc] initWithPrimitive:(xmlKindPtr)copyDtdPtr owner:nil];
	}
	
	return nil;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Equality
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)isEqual:(id)anObject
{
	// DDXMLNode, DDXMLElement, and DDXMLDocument are simply light-weight wrappers atop a libxml structure.
	// 
	// To provide maximum speed and thread-safety,
	// multiple DDXML wrapper objects may be created that wrap the same underlying libxml node.
	// 
	// Thus equality is simply a matter of what underlying libxml node DDXML is wrapping.
	
	if ([anObject class] == [self class])
	{
		DDXMLNode *aNode = (DDXMLNode *)anObject;
		
		return (genericPtr == aNode->genericPtr);
	}
	
	return NO;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Properties
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (DDXMLNodeKind)kind
{
	DDXMLNotZombieAssert();
	
	if (genericPtr != NULL)
		return genericPtr->type;
	else
		return DDXMLInvalidKind;
}

- (void)setName:(NSString *)name
{
	DDXMLCheckAndSetErrorHandlerForCurrentThread();
	
	// Note: DDXMLNamespaceNode overrides this method
	
	DDXMLNotZombieAssert();
	
	// The xmlNodeSetName function works for both nodes and attributes
	xmlNodeSetName((xmlNodePtr)genericPtr, (const xmlChar *)[name UTF8String]);
}

- (NSString *)name
{
	// Note: DDXMLNamespaceNode overrides this method
	// Note: DDXMLAttributeNode overrides this method
	
	DDXMLNotZombieAssert();
	
	const xmlChar *xmlName = ((xmlStdPtr)genericPtr)->name;
	if (xmlName == NULL)
	{
		return nil;
	}
	
	NSString *name = [NSString stringWithUTF8String:(const char *)xmlName];
	
	if (IsXmlNodePtr(genericPtr))
	{
		xmlNodePtr node = (xmlNodePtr)genericPtr;
		
		NSRange range = [name rangeOfString:@":"];
		if (range.length == 0)
		{
			if (node->ns && node->ns->prefix)
			{
				return [NSString stringWithFormat:@"%s:%@", node->ns->prefix, name];
			}
		}
	}
	
	return name;
}

- (void)setStringValue:(NSString *)string
{
	DDXMLCheckAndSetErrorHandlerForCurrentThread();
	
	// Note: DDXMLNamespaceNode overrides this method
	// Note: DDXMLAttributeNode overrides this method
	
	DDXMLNotZombieAssert();
	
	if (IsXmlNodePtr(genericPtr))
	{
		xmlStdPtr node = (xmlStdPtr)genericPtr;
		
		// Setting the content of a node erases any existing child nodes.
		// Therefore, we need to remove them properly first.
		[[self class] removeAllChildrenFromNode:(xmlNodePtr)node];
		
		xmlChar *escapedString = xmlEncodeSpecialChars(node->doc, (const xmlChar *)[string UTF8String]);
		xmlNodeSetContent((xmlNodePtr)node, escapedString);
		xmlFree(escapedString);
	}
}

/**
 * Returns the content of the receiver as a string value.
 * 
 * If the receiver is a node object of element kind, the content is that of any text-node children.
 * This method recursively visits elements nodes and concatenates their text nodes in document order with
 * no intervening spaces.
**/
- (NSString *)stringValue
{
	DDXMLCheckAndSetErrorHandlerForCurrentThread();
	
	// Note: DDXMLNamespaceNode overrides this method
	// Note: DDXMLAttributeNode overrides this method
	
	DDXMLNotZombieAssert();
	
	if (IsXmlNodePtr(genericPtr))
	{
		xmlChar *content = xmlNodeGetContent((xmlNodePtr)genericPtr);
		
		NSString *result = [NSString stringWithUTF8String:(const char *)content];
		
		xmlFree(content);
		return result;
	}
	
	return nil;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Tree Navigation
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns the index of the receiver identifying its position relative to its sibling nodes.
 * The first child node of a parent has an index of zero.
**/
- (NSUInteger)index
{
	// Note: DDXMLNamespaceNode overrides this method
	
	DDXMLNotZombieAssert();
	
	NSUInteger result = 0;
	
	xmlStdPtr node = ((xmlStdPtr)genericPtr)->prev;
	while (node != NULL)
	{
		result++;
		node = node->prev;
	}
	
	return result;
}

/**
 * Returns the nesting level of the receiver within the tree hierarchy.
 * The root element of a document has a nesting level of one.
**/
- (NSUInteger)level
{
	// Note: DDXMLNamespaceNode overrides this method
	
	DDXMLNotZombieAssert();
	
	NSUInteger result = 0;
	
	xmlNodePtr currentNode = ((xmlStdPtr)genericPtr)->parent;
	while (currentNode != NULL)
	{
		result++;
		currentNode = currentNode->parent;
	}
	
	return result;
}

/**
 * Returns the DDXMLDocument object containing the root element and representing the XML document as a whole.
 * If the receiver is a standalone node (that is, a node at the head of a detached branch of the tree), this
 * method returns nil.
**/
- (DDXMLDocument *)rootDocument
{
	// Note: DDXMLNamespaceNode overrides this method
	
	DDXMLNotZombieAssert();
	
	xmlStdPtr node = (xmlStdPtr)genericPtr;
	
	if (node == NULL || node->doc == NULL)
		return nil;
	else
		return [DDXMLDocument nodeWithDocPrimitive:node->doc owner:self];
}

/**
 * Returns the parent node of the receiver.
 * 
 * Document nodes and standalone nodes (that is, the root of a detached branch of a tree) have no parent, and
 * sending this message to them returns nil. A one-to-one relationship does not always exists between a parent and
 * its children; although a namespace or attribute node cannot be a child, it still has a parent element.
**/
- (DDXMLNode *)parent
{
	// Note: DDXMLNamespaceNode overrides this method
	
	DDXMLNotZombieAssert();
	
	xmlStdPtr node = (xmlStdPtr)genericPtr;
	
	if (node->parent == NULL)
		return nil;
	else
		return [DDXMLNode nodeWithUnknownPrimitive:(xmlKindPtr)node->parent owner:self];
}

/**
 * Returns the number of child nodes the receiver has.
 * For performance reasons, use this method instead of getting the count from the array returned by children.
**/
- (NSUInteger)childCount
{
	// Note: DDXMLNamespaceNode overrides this method
	
	DDXMLNotZombieAssert();
	
	if (!IsXmlDocPtr(genericPtr) && !IsXmlNodePtr(genericPtr) && !IsXmlDtdPtr(genericPtr))
	{
		return 0;
	}
	
	NSUInteger result = 0;
	
	xmlNodePtr child = ((xmlStdPtr)genericPtr)->children;
	while (child != NULL)
	{
		result++;
		child = child->next;
	}
	
	return result;
}

/**
 * Returns an immutable array containing the child nodes of the receiver (as DDXMLNode objects).
**/
- (NSArray *)children
{
	// Note: DDXMLNamespaceNode overrides this method
	
	DDXMLNotZombieAssert();
	
	if (!IsXmlDocPtr(genericPtr) && !IsXmlNodePtr(genericPtr) && !IsXmlDtdPtr(genericPtr))
	{
		return nil;
	}
	
	NSMutableArray *result = [NSMutableArray array];
	
	xmlNodePtr child = ((xmlStdPtr)genericPtr)->children;
	while (child != NULL)
	{
		[result addObject:[DDXMLNode nodeWithUnknownPrimitive:(xmlKindPtr)child owner:self]];
		
		child = child->next;
	}
	
	return [[result copy] autorelease];
}

/**
 * Returns the child node of the receiver at the specified location.
 * Returns a DDXMLNode object or nil if the receiver has no children.
 * 
 * If the receive has children and index is out of bounds, an exception is raised.
 * 
 * The receiver should be a DDXMLNode object representing a document, element, or document type declaration.
 * The returned node object can represent an element, comment, text, or processing instruction.
**/
- (DDXMLNode *)childAtIndex:(NSUInteger)idx
{
	// Note: DDXMLNamespaceNode overrides this method
	
	DDXMLNotZombieAssert();
	
	if (!IsXmlDocPtr(genericPtr) && !IsXmlNodePtr(genericPtr) && !IsXmlDtdPtr(genericPtr))
	{
		return nil;
	}
	
	NSUInteger i = 0;
	
	xmlNodePtr child = ((xmlStdPtr)genericPtr)->children;
	
	if (child == NULL)
	{
		// NSXML doesn't raise an exception if there are no children
		return nil;
	}
	
	while (child != NULL)
	{
		if (i == idx)
		{
			return [DDXMLNode nodeWithUnknownPrimitive:(xmlKindPtr)child owner:self];
		}
		
		i++;
		child = child->next;
	}
	
	// NSXML version uses this same assertion
	DDXMLAssert(NO, @"index (%u) beyond bounds (%u)", (unsigned)idx, (unsigned)i);
	
	return nil;
}

/**
 * Returns the previous DDXMLNode object that is a sibling node to the receiver.
 * 
 * This object will have an index value that is one less than the receiver's.
 * If there are no more previous siblings (that is, other child nodes of the receiver's parent) the method returns nil.
**/
- (DDXMLNode *)previousSibling
{
	// Note: DDXMLNamespaceNode overrides this method
	
	DDXMLNotZombieAssert();
	
	xmlStdPtr node = (xmlStdPtr)genericPtr;
	
	if (node->prev == NULL)
		return nil;
	else
		return [DDXMLNode nodeWithUnknownPrimitive:(xmlKindPtr)node->prev owner:self];
}

/**
 * Returns the next DDXMLNode object that is a sibling node to the receiver.
 * 
 * This object will have an index value that is one more than the receiver's.
 * If there are no more subsequent siblings (that is, other child nodes of the receiver's parent) the
 * method returns nil.
**/
- (DDXMLNode *)nextSibling
{
	// Note: DDXMLNamespaceNode overrides this method
	
	DDXMLNotZombieAssert();
	
	xmlStdPtr node = (xmlStdPtr)genericPtr;
	
	if (node->next == NULL)
		return nil;
	else
		return [DDXMLNode nodeWithUnknownPrimitive:(xmlKindPtr)node->next owner:self];
}

/**
 * Returns the previous DDXMLNode object in document order.
 * 
 * You use this method to ÒwalkÓ backward through the tree structure representing an XML document or document section.
 * (Use nextNode to traverse the tree in the opposite direction.) Document order is the natural order that XML
 * constructs appear in markup text. If you send this message to the first node in the tree (that is, the root element),
 * nil is returned. DDXMLNode bypasses namespace and attribute nodes when it traverses a tree in document order.
**/
- (DDXMLNode *)previousNode
{
	// Note: DDXMLNamespaceNode overrides this method
	// Note: DDXMLAttributeNode overrides this method
	
	DDXMLNotZombieAssert();
	
	// If the node has a previous sibling,
	// then we need the last child of the last child of the last child etc
	
	// Note: Try to accomplish this task without creating dozens of intermediate wrapper objects
	
	xmlStdPtr node = (xmlStdPtr)genericPtr;
	xmlStdPtr previousSibling = node->prev;
	
	if (previousSibling != NULL)
	{
		if (previousSibling->last != NULL)
		{
			xmlNodePtr lastChild = previousSibling->last;
			while (lastChild->last != NULL)
			{
				lastChild = lastChild->last;
			}
			
			return [DDXMLNode nodeWithUnknownPrimitive:(xmlKindPtr)lastChild owner:self];
		}
		else
		{
			// The previous sibling has no children, so the previous node is simply the previous sibling
			return [DDXMLNode nodeWithUnknownPrimitive:(xmlKindPtr)previousSibling owner:self];
		}
	}
	
	// If there are no previous siblings, then the previous node is simply the parent
	
	// Note: rootNode.parent == docNode
	
	if (node->parent == NULL || node->parent->type == XML_DOCUMENT_NODE)
		return nil;
	else
		return [DDXMLNode nodeWithUnknownPrimitive:(xmlKindPtr)node->parent owner:self];
}

/**
 * Returns the next DDXMLNode object in document order.
 * 
 * You use this method to ÒwalkÓ forward through the tree structure representing an XML document or document section.
 * (Use previousNode to traverse the tree in the opposite direction.) Document order is the natural order that XML
 * constructs appear in markup text. If you send this message to the last node in the tree, nil is returned.
 * DDXMLNode bypasses namespace and attribute nodes when it traverses a tree in document order.
**/
- (DDXMLNode *)nextNode
{
	// Note: DDXMLNamespaceNode overrides this method
	// Note: DDXMLAttributeNode overrides this method
	
	DDXMLNotZombieAssert();
	
	// If the node has children, then next node is the first child
	DDXMLNode *firstChild = [self childAtIndex:0];
	if (firstChild)
		return firstChild;
	
	// If the node has a next sibling, then next node is the same as next sibling
	
	DDXMLNode *nextSibling = [self nextSibling];
	if (nextSibling)
		return nextSibling;
	
	// There are no children, and no more siblings, so we need to get the next sibling of the parent.
	// If that is nil, we need to get the next sibling of the grandparent, etc.
	
	// Note: Try to accomplish this task without creating dozens of intermediate wrapper objects
	
	xmlNodePtr parent = ((xmlStdPtr)genericPtr)->parent;
	while (parent != NULL)
	{
		xmlNodePtr parentNextSibling = parent->next;
		if (parentNextSibling != NULL)
			return [DDXMLNode nodeWithUnknownPrimitive:(xmlKindPtr)parentNextSibling owner:self];
		else
			parent = parent->parent;
	}
	
	return nil;
}

/**
 * Detaches the receiver from its parent node.
 *
 * This method is applicable to DDXMLNode objects representing elements, text, comments, processing instructions,
 * attributes, and namespaces. Once the node object is detached, you can add it as a child node of another parent.
**/
- (void)detach
{
	// Note: DDXMLNamespaceNode overrides this method
	// Note: DDXMLAttributeNode overrides this method
	
	DDXMLNotZombieAssert();
	
	xmlStdPtr node = (xmlStdPtr)genericPtr;
	
	if (node->parent != NULL)
	{
		if (IsXmlNodePtr(genericPtr))
		{
			[[self class] detachChild:(xmlNodePtr)node];
			
			[owner release];
			owner = nil;
		}
	}
}

- (xmlStdPtr)_XPathPreProcess:(NSMutableString *)result
{
	// This is a private/internal method
	
	// Note: DDXMLNamespaceNode overrides this method
	// Note: DDXMLAttributeNode overrides this method
	
	return (xmlStdPtr)genericPtr;
}

- (NSString *)XPath
{
	DDXMLNotZombieAssert();
	
	NSMutableString *result = [NSMutableString stringWithCapacity:25];
	
	// Examples:
	// /rootElement[1]/subElement[4]/thisNode[2]
	// topElement/thisNode[2]
	
	xmlStdPtr node = [self _XPathPreProcess:result];
	
	// Note: rootNode.parent == docNode
		
	while ((node != NULL) && (node->type != XML_DOCUMENT_NODE))
	{
		if ((node->parent == NULL) && (node->doc == NULL))
		{
			// We're at the top of the heirarchy, and there is no xml document.
			// Thus we don't use a leading '/', and we don't need an index.
			
			[result insertString:[NSString stringWithFormat:@"%s", node->name] atIndex:0];
		}
		else
		{
			// Find out what index this node is.
			// If it's the first node with this name, the index is 1.
			// If there are previous siblings with the same name, the index is greater than 1.
			
			int idx = 1;
			xmlStdPtr prevNode = node->prev;
			
			while (prevNode != NULL)
			{
				if (xmlStrEqual(node->name, prevNode->name))
				{
					idx++;
				}
				prevNode = prevNode->prev;
			}
			
			[result insertString:[NSString stringWithFormat:@"/%s[%i]", node->name, idx] atIndex:0];
		}
		
		node = (xmlStdPtr)node->parent;
	}
	
	return [[result copy] autorelease];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark QNames
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Returns the local name of the receiver.
 * 
 * The local name is the part of a node name that follows a namespace-qualifying colon or the full name if
 * there is no colon. For example, ÒchapterÓ is the local name in the qualified name Òacme:chapterÓ.
**/
- (NSString *)localName
{
	// Note: DDXMLNamespaceNode overrides this method
	
	// Zombie test occurs in [self name]
	
	return [[self class] localNameForName:[self name]];
}

/**
 * Returns the prefix of the receiver's name.
 * 
 * The prefix is the part of a namespace-qualified name that precedes the colon.
 * For example, ÒacmeÓ is the local name in the qualified name Òacme:chapterÓ.
 * This method returns an empty string if the receiver's name is not qualified by a namespace.
**/
- (NSString *)prefix
{
	// Note: DDXMLNamespaceNode overrides this method
	
	// Zombie test occurs in [self name]
	
	return [[self class] prefixForName:[self name]];
}

/**
 * Sets the URI identifying the source of this document.
 * Pass nil to remove the current URI.
**/
- (void)setURI:(NSString *)URI
{
	DDXMLCheckAndSetErrorHandlerForCurrentThread();
	
	// Note: DDXMLNamespaceNode overrides this method
	// Note: DDXMLAttributeNode overrides this method
	
	DDXMLNotZombieAssert();
	
	if (IsXmlNodePtr(genericPtr))
	{
		xmlNodePtr node = (xmlNodePtr)genericPtr;
		if (node->ns != NULL)
		{
			[[self class] removeNamespace:node->ns fromNode:node];
		}
		
		if (URI)
		{
			// Create a new xmlNsPtr, add it to the nsDef list, and make ns point to it
			xmlNsPtr ns = xmlNewNs(NULL, (const xmlChar *)[URI UTF8String], NULL);
			ns->next = node->nsDef;
			node->nsDef = ns;
			node->ns = ns;
		}
	}
}

/**
 * Returns the URI associated with the receiver.
 * 
 * A nodeÕs URI is derived from its namespace or a documentÕs URI; for documents, the URI comes either from the
 * parsed XML or is explicitly set. You cannot change the URI for a particular node other for than a namespace
 * or document node.
**/
- (NSString *)URI
{
	// Note: DDXMLNamespaceNode overrides this method
	// Note: DDXMLAttributeNode overrides this method
	
	DDXMLNotZombieAssert();
	
	if (IsXmlNodePtr(genericPtr))
	{
		xmlNodePtr node = (xmlNodePtr)genericPtr;
		if (node->ns != NULL)
		{
			return [NSString stringWithUTF8String:((const char *)node->ns->href)];
		}
	}
	
	return nil;
}

+ (void)getHasPrefix:(BOOL *)hasPrefixPtr localName:(NSString **)localNamePtr forName:(NSString *)name
{
	// This is a private/internal method
	
	if (name)
	{
		NSRange range = [name rangeOfString:@":"];
		
		if (range.length != 0)
		{
			if (hasPrefixPtr) *hasPrefixPtr = range.location > 0;
			if (localNamePtr) *localNamePtr = [name substringFromIndex:(range.location + range.length)];
		}
		else
		{
			if (hasPrefixPtr) *hasPrefixPtr = NO;
			if (localNamePtr) *localNamePtr = name;
		}
	}
	else
	{
		if (hasPrefixPtr) *hasPrefixPtr = NO;
		if (localNamePtr) *localNamePtr = nil;
	}
}

+ (void)getPrefix:(NSString **)prefixPtr localName:(NSString **)localNamePtr forName:(NSString *)name
{
	// This is a private/internal method
	
	if (name)
	{
		NSRange range = [name rangeOfString:@":"];
		
		if (range.length != 0)
		{
			if (prefixPtr)    *prefixPtr    = [name substringToIndex:range.location];
			if (localNamePtr) *localNamePtr = [name substringFromIndex:(range.location + range.length)];
		}
		else
		{
			if (prefixPtr)    *prefixPtr    = @"";
			if (localNamePtr) *localNamePtr = name;
		}
	}
	else
	{
		if (prefixPtr)    *prefixPtr    = @"";
		if (localNamePtr) *localNamePtr = nil;
	}
}

/**
 * Returns the local name from the specified qualified name.
 * 
 * Examples:
 * "a:node" -> "node"
 * "a:a:node" -> "a:node"
 * "node" -> "node"
 * nil - > nil
**/
+ (NSString *)localNameForName:(NSString *)name
{
	// This is a public/API method
	
	NSString *localName;
	[self getPrefix:NULL localName:&localName forName:name];
	
	return localName;
}

/**
 * Extracts the prefix from the given name.
 * If name is nil, or has no prefix, an empty string is returned.
 * 
 * Examples:
 * "a:deusty.com" -> "a"
 * "a:a:deusty.com" -> "a"
 * "node" -> ""
 * nil -> ""
**/
+ (NSString *)prefixForName:(NSString *)name
{
	// This is a public/API method
	
	NSString *prefix;
	[self getPrefix:&prefix localName:NULL forName:name];
	
	return prefix;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Output
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)description
{
	// Zombie test occurs in XMLStringWithOptions:
	
	return [self XMLStringWithOptions:0];
}

- (NSString *)XMLString
{
	// Zombie test occurs in XMLStringWithOptions:
	
	return [self XMLStringWithOptions:0];
}

- (NSString *)XMLStringWithOptions:(NSUInteger)options
{
	DDXMLCheckAndSetErrorHandlerForCurrentThread();
	
	DDXMLNotZombieAssert();
	
	// xmlSaveNoEmptyTags:
	// Global setting, asking the serializer to not output empty tags
	// as <empty/> but <empty></empty>. those two forms are undistinguishable
	// once parsed.
	// Disabled by default
	
	if (options & DDXMLNodeCompactEmptyElement)
		xmlSaveNoEmptyTags = 0;
	else
		xmlSaveNoEmptyTags = 1;
	
	int format = 0;
	if (options & DDXMLNodePrettyPrint)
	{
		format = 1;
		xmlIndentTreeOutput = 1;
	}
	
	int dumpCnt;
	
	xmlBufferPtr bufferPtr = xmlBufferCreate();
	if (IsXmlNsPtr(genericPtr))
		dumpCnt = xmlNodeDump(bufferPtr, NULL, (xmlNodePtr)genericPtr, 0, format);
	else
		dumpCnt = xmlNodeDump(bufferPtr, ((xmlStdPtr)genericPtr)->doc, (xmlNodePtr)genericPtr, 0, format);
	
	if (dumpCnt < 0)
	{
		return nil;
	}
	
	if ([self kind] == DDXMLTextKind)
	{
		NSString *result = [NSString stringWithUTF8String:(const char *)bufferPtr->content];
		
		xmlBufferFree(bufferPtr);
		
		return result;
	}
	else
	{
		NSMutableString *resTmp = [NSMutableString stringWithUTF8String:(const char *)bufferPtr->content];
		CFStringTrimWhitespace((CFMutableStringRef)resTmp);
		
		xmlBufferFree(bufferPtr);
		
		return [[resTmp copy] autorelease];
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XPath/XQuery
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSArray *)nodesForXPath:(NSString *)XPath error:(NSError **)errorRef
{
	return [self nodesForXPath:XPath namespaceMap:nil error:errorRef];
}

#define dd_scoped_block_t dispatch_block_t __attribute__((unused)) __attribute__((cleanup(_DDXMLCallScopedBlock)))

static inline void _DDXMLCallScopedBlock(dispatch_block_t const *blockRef) {
	if (*blockRef != NULL) {
		(*blockRef)();
	}
}

- (NSArray *)nodesForXPath:(NSString *)XPath namespaceMap:(NSDictionary *)namespaceMap error:(NSError **)errorRef
{
	DDXMLCheckAndSetErrorHandlerForCurrentThread();
	
	DDXMLNotZombieAssert();
	
	xmlDocPtr document = NULL;
	BOOL isTemporaryDocument = NO;
	
	if (IsXmlDocPtr(genericPtr)) {
		document = (xmlDocPtr)genericPtr;
	}
	else if (IsXmlNodePtr(genericPtr)) {
		document = ((xmlNodePtr)genericPtr)->doc;
		
		if (document == NULL)
		{
			document = xmlNewDoc(NULL);
			xmlDocSetRootElement(document, (xmlNodePtr)genericPtr);
			
			isTemporaryDocument = YES;
		}
	}
	else {
		if (errorRef != NULL) {
			*errorRef = [NSError errorWithDomain:DDXMLBundleIdentifier code:DDXMLErrorCodeUnknown userInfo:nil];
		}
		return nil;
	}
	
	dd_scoped_block_t cleanupDocument = ^ {
		if (!isTemporaryDocument) {
			return;
		}
		
		xmlUnlinkNode((xmlNodePtr)genericPtr);
		xmlFreeDoc(document);
		
		// xmlUnlinkNode doesn't remove the doc ptr
		[[self class] recursiveStripDocPointersFromNode:(xmlNodePtr)genericPtr];
	};
	
	xmlXPathContextPtr xpathCtx = xmlXPathNewContext(document);
	xpathCtx->node = (xmlNodePtr)genericPtr;
	
	dd_scoped_block_t cleanupXpathCtx = ^ {
		xmlXPathFreeContext(xpathCtx);
	};
	
	void (^registerNamespace)(NSString *prefix, NSString *URI) = ^ void (NSString *prefix, NSString *URI) {
		const xmlChar *prefixString = (const xmlChar *)[prefix UTF8String];
		const xmlChar *URIString = (const xmlChar *)[URI UTF8String];
		
		xmlXPathRegisterNs(xpathCtx, prefixString, URIString);
	};
	
	BOOL mimicNSXMLNodeBehaviour = (namespaceMap == nil);
	if (mimicNSXMLNodeBehaviour) {
		/*
			Note
			
			XPath has no notion of a default namespace, unqualified node names are assumed to belong to the null namespace
			
			for more details see:
			<http://mail.gnome.org/archives/xml/2003-April/msg00144.html>
			<http://www.perlmonks.org/?node_id=530519>
			
			===================================================================================================================
			
			following an analysis of -[NSXMLNode nodesForXPath:error:] it seems that it uses XQuery unconditionally
			
			we will need to investigate the behaviour of XQuery with respect to default node namespaces
			
			one possible solution would be to register the default namespace with a __default__ prefix (inserting characters as needed to make this prefix unique)
			
			then we'd preprocess the XPath, similar to `RMFoundationXPathPreprocess()` to insert that prefix in front of all unqualified node names
			
			that said, we might be better off just deprecating this whole shebang, and just not supporting 'default namespace' XPath NSXML like behaviour
			
			requiring clients to be explicit in their namespace declarations
			
			===================================================================================================================
			
			following further analysis we have turned both the best guess implementation _and_ the error, off
			
			this is to support `RMFoundationXPathPreprocess()` XPath strings which don't rely on the prefix being fixed inside a document
			
			otherwise we have no way to detect this supported use case
			
			mimicNSXMLNodeBehaviour queries will now just fail to return results if the document has namespaced nodes
		 */
		//nop
	}
	else {
		[namespaceMap enumerateKeysAndObjectsUsingBlock:^ (id namespaceMapKey, id namespaceMapObj, BOOL *stopEnumeratingNamespaceMap) {
			registerNamespace(namespaceMapKey, namespaceMapObj);
		}];
	}
	
	xmlXPathObjectPtr xpathObj = xmlXPathEvalExpression((const xmlChar *)[XPath UTF8String], xpathCtx);
	if (xpathObj == NULL) {
		if (errorRef != NULL) {
			*errorRef = [[self class] lastError];
		}
		return nil;
	}
	
	dd_scoped_block_t cleanupXpathObj = ^ {
		xmlXPathFreeObject(xpathObj);
	};
	
	NSArray *result = nil;
	
	int count = xmlXPathNodeSetGetLength(xpathObj->nodesetval);
	if (count == 0) {
		result = [NSArray array];
	}
	else {
		NSMutableArray *mResult = [NSMutableArray arrayWithCapacity:count];
		
		for (int i = 0; i < count; i++)
		{
			xmlNodePtr node = xpathObj->nodesetval->nodeTab[i];
			[mResult addObject:[DDXMLNode nodeWithUnknownPrimitive:(xmlKindPtr)node owner:self]];
		}
		
		result = mResult;
	}
	
	return result;
}

#undef dd_scoped_block_t

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Private API
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// ---------- MEMORY MANAGEMENT ARCHITECTURE ----------
// 
// KissXML is designed to be read-access thread-safe.
// It is not write-access thread-safe as this would require significant overhead.
// 
// What exactly does read-access thread-safe mean?
// It means that multiple threads can safely read from the same xml structure,
// so long as none of them attempt to alter the xml structure (add/remove nodes, change attributes, etc).
// 
// This read-access thread-safety includes parsed xml structures as well as xml structures created by you.
// Let's walk through a few examples to get a deeper understanding.
// 
// 
// 
// Example #1 - Parallel processing of children
// 
// DDXMLElement *root = [[DDXMLElement alloc] initWithXMLString:str error:nil];
// NSArray *children = [root children];
// 
// dispatch_queue_t q = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
// dispatch_apply([children count], q, ^(size_t i) {
//     DDXMLElement *child = [children objectAtIndex:i];
//     <process child>
// });
// 
// 
// 
// Example #2 - Asynchronous child processing
// 
// DDXMLElement *root = [[DDXMLElement alloc] initWithXMLString:str error:nil];
// DDXMLElement *child = [root elementForName:@"starbucks"];
// 
// dispatch_async(queue, ^{
//     <process child>
// });
// 
// [root release];
// 
// You may have noticed that we possibly released the root node before the child was processed.
// Is this safe?
// 
// The answer is YES.
// The child node retains a reference to the root node,
// so the xml tree heirarchy won't be freed until you're done using all associated nodes.
// 
// 
// 


/**
 * Returns whether or not the node has a parent.
 * Use this method instead of parent when you only need to ensure parent is nil.
 * This prevents the unnecessary creation of a parent node wrapper.
**/
- (BOOL)hasParent
{
	// This is a private/internal method
	
	// Note: DDXMLNamespaceNode overrides this method
	
	xmlStdPtr node = (xmlStdPtr)genericPtr;
	
	return (node->parent != NULL);
}

+ (void)stripDocPointersFromAttr:(xmlAttrPtr)attr
{
	xmlNodePtr child = attr->children;
	while (child != NULL)
	{
		child->doc = NULL;
		child = child->next;
	}
	
	attr->doc = NULL;
}

+ (void)recursiveStripDocPointersFromNode:(xmlNodePtr)node
{
	xmlAttrPtr attr = node->properties;
	while (attr != NULL)
	{
		[self stripDocPointersFromAttr:attr];
		attr = attr->next;
	}
	
	xmlNodePtr child = node->children;
	while (child != NULL)
	{
		[self recursiveStripDocPointersFromNode:child];
		child = child->next;
	}
	
	node->doc = NULL;
}

/**
 * If node->ns is pointing to the given ns, the pointer is nullified.
 * The same goes for any attributes and childrend of node.
**/
+ (void)recursiveStripNamespace:(xmlNsPtr)ns fromNode:(xmlNodePtr)node
{
	if (node->ns == ns)
	{
		node->ns = NULL;
	}
	
	xmlAttrPtr attr = node->properties;
	while (attr)
	{
		if (attr->ns == ns)
		{
			attr->ns = NULL;
		}
		attr = attr->next;
	}
	
	xmlNodePtr child = node->children;
	while (child)
	{
		[self recursiveStripNamespace:ns fromNode:child];
		child = child->next;
	}
}

/**
 * If node or any of its attributes or children are referencing the the given old namespace,
 * they are migrated to reference the new namespace instead.
 * 
 * If newNs is NULL, and a reference to oldNs is found, then oldNs is copied,
 * and the copy is used for the remainder of the recursion.
 * 
 * This method makes copies of oldNs as needed so that oldNs can be cleanly detached from the tree.
**/
+ (void)recursiveMigrateNamespace:(xmlNsPtr)oldNs to:(xmlNsPtr)newNs node:(xmlNodePtr)node
{
	DDXMLCheckAndSetErrorHandlerForCurrentThread();
	
	// Do we need to copy old namespace?
	
	if (newNs == NULL)
	{
		// A copy needs to be made if:
		//  * node->ns == oldNs
		//  * attr->ns == oldNs
		// 
		// Remember: The namespaces in node->nsDef are owned by node.
		//           That's not what we're migrating.
		
		BOOL needsCopy = (node->ns == oldNs);
		
		if (!needsCopy)
		{
			xmlAttrPtr attr = node->properties;
			while (attr)
			{
				if (attr->ns == oldNs)
				{
					needsCopy = YES;
					break;
				}
				attr = attr->next;
			}
		}
		
		if (needsCopy)
		{
			// Copy oldNs, and place at the end of the node's namspace list
			newNs = xmlNewNs(NULL, oldNs->href, oldNs->prefix);
			
			if (node->nsDef == NULL)
			{
				node->nsDef = newNs;
			}
			else
			{
				xmlNsPtr lastNs = node->nsDef;
				while (lastNs->next)
				{
					lastNs = lastNs->next;
				}
				
				lastNs->next = newNs;
			}
		}
	}
	
	// Migrate node & attributes
	
	if (newNs)
	{
		if (node->ns == oldNs)
		{
			node->ns = newNs;
		}
		
		xmlAttrPtr attr = node->properties;
		while (attr)
		{
			if (attr->ns == oldNs)
			{
				attr->ns = newNs;
			}
			attr = attr->next;
		}
	}
	
	// Migrate children
	
	xmlNodePtr child = node->children;
	while (child)
	{
		[self recursiveMigrateNamespace:oldNs to:newNs node:child];
		child = child->next;
	}
}

/**
 * If node has a default namespace allocated outside the given root,
 * this method copies the namespace so that the given root can be cleanly detached from its tree.
**/
+ (void)recursiveFixDefaultNamespacesInNode:(xmlNodePtr)node withNewRoot:(xmlNodePtr)rootNode
{
	NSAssert(rootNode != NULL, @"Must specify rootNode.");
	
	DDXMLCheckAndSetErrorHandlerForCurrentThread();
	
	// Step 1 of 3
	// 
	// Copy our namespace.
	// It's important to do this first (before the other steps).
	// This way attributes and children can reference our copy. (prevents multiple copies throughout tree)
	
	xmlNsPtr nodeNs = node->ns;
	if (nodeNs)
	{
		// Does the namespace reside within the new root somewhere?
		// We can find out by searching for it in nsDef lists up to the given root.
		
		BOOL nsResidesWithinNewRoot = NO;
		
		xmlNodePtr treeNode = node;
		while (treeNode)
		{
			xmlNsPtr treeNs = treeNode->nsDef;
			while (treeNs)
			{
				if (treeNs == nodeNs)
				{
					nsResidesWithinNewRoot = YES;
					break;
				}
				
				treeNs = treeNs->next;
			}
			
			if (nsResidesWithinNewRoot || treeNode == rootNode)
				treeNode = NULL;
			else
				treeNode = treeNode->parent;
		}
		
		if (!nsResidesWithinNewRoot)
		{
			// Create a copy of the namespace, add to nsDef list, and then set as ns
			xmlNsPtr nodeNsCopy = xmlNewNs(NULL, nodeNs->href, nodeNs->prefix);
			
			nodeNsCopy->next = node->nsDef;
			node->nsDef = nodeNsCopy;
			
			node->ns = nodeNsCopy;
		}
	}
	
	// Step 2 of 3
	// 
	// If any attributes are referencing namespaces outside the new root,
	// copy the namespaces into node, and have the attributes reference the copy.
	
	xmlAttrPtr attr = node->properties;
	while (attr)
	{
		xmlNsPtr attrNs = attr->ns;
		while (attrNs)
		{
			BOOL nsResidesWithinNewRoot = NO;
			
			xmlNodePtr treeNode = node;
			while (treeNode)
			{
				xmlNsPtr treeNs = treeNode->nsDef;
				while (treeNs)
				{
					if (treeNs == attrNs)
					{
						nsResidesWithinNewRoot = YES;
						break;
					}
					
					treeNs = treeNs->next;
				}
				
				if (nsResidesWithinNewRoot || treeNode == rootNode)
					treeNode = NULL;
				else
					treeNode = treeNode->parent;
			}
			
			if (!nsResidesWithinNewRoot)
			{
				// Create a copy of the namespace, add to node's nsDef list, and then set as attribute's ns
				xmlNsPtr attrNsCopy = xmlNewNs(NULL, attrNs->href, attrNs->prefix);
				
				attrNsCopy->next = node->nsDef;
				node->nsDef = attrNsCopy;
				
				attr->ns = attrNsCopy;
			}
			
			attrNs = attrNs->next;
		}
		
		attr = attr->next;
	}
	
	// Step 3 of 3
	// 
	// Copy namespaces into children
	
	xmlNodePtr childNode = node->children;
	while (childNode)
	{
		[self recursiveFixDefaultNamespacesInNode:childNode withNewRoot:rootNode];
		
		childNode = childNode->next;
	}
}

/**
 * Detaches the given namespace from the given node.
 * The namespace's surrounding next pointers are properly updated to remove the namespace from the node's nsDef list.
 * Then the namespace's parent and next pointers are destroyed.
**/
+ (void)detachNamespace:(xmlNsPtr)ns fromNode:(xmlNodePtr)node
{
	// If node, or any of node's attributes are referring to this namespace,
	// then we need to nullify those references.
	// 
	// However, if any children are referring to this namespace,
	// then we instruct those children to make copies.
	
	if (node->ns == ns)
	{
		node->ns = NULL;
	}
	
	xmlAttrPtr attr = node->properties;
	while (attr)
	{
		if (attr->ns == ns)
		{
			attr->ns = NULL;
		}
		attr = attr->next;
	}
	
	xmlNodePtr child = node->children;
	while (child)
	{
		[self recursiveMigrateNamespace:ns to:NULL node:child];
		child = child->next;
	}
	
	// Now detach namespace from the namespace list.
	// 
	// Namespace nodes have no previous pointer, so we have to search for the node
	
	xmlNsPtr previousNs = NULL;
	xmlNsPtr currentNs = node->nsDef;
	
	while (currentNs != NULL)
	{
		if (currentNs == ns)
		{
			if (previousNs == NULL)
				node->nsDef = currentNs->next;
			else
				previousNs->next = currentNs->next;
			
			break;
		}
		
		previousNs = currentNs;
		currentNs = currentNs->next;
	}
	
	// Nullify pointers
	ns->next = NULL;
}

/**
 * Removes the given namespace from the given node.
 * The namespace's surrounding next pointers are properly updated to remove the namespace from the nsDef list.
 * Then the namespace is freed if it's no longer being referenced.
 * Otherwise, it's nsParent and next pointers are destroyed.
**/
+ (void)removeNamespace:(xmlNsPtr)ns fromNode:(xmlNodePtr)node
{
	DDXMLCheckAndSetErrorHandlerForCurrentThread();
	
#if DDXML_DEBUG_MEMORY_ISSUES
	MarkZombies(ns);
#endif
	
	[self detachNamespace:ns fromNode:node];
	
	xmlFreeNs(ns);
}

/**
 * Removes all namespaces from the given node.
 * All namespaces are either freed, or their nsParent and next pointers are properly destroyed.
 * Upon return, the given node's nsDef pointer is NULL.
**/
+ (void)removeAllNamespacesFromNode:(xmlNodePtr)node
{
	DDXMLCheckAndSetErrorHandlerForCurrentThread();
	
	xmlNsPtr ns = node->nsDef;
	while (ns != NULL)
	{
		xmlNsPtr nextNs = ns->next;
		
	#if DDXML_DEBUG_MEMORY_ISSUES
		MarkZombies(ns);
	#endif
		
		xmlFreeNs(ns);
		ns = nextNs;
	}
	
	node->nsDef = NULL;
	node->ns = NULL;
}

/**
 * Detaches the given attribute from its parent node.
 * The attribute's surrounding prev/next pointers are properly updated to remove the attribute from the attr list.
 * Then, if the clean flag is YES, the attribute's parent, prev, next and doc pointers are set to null.
**/
+ (void)detachAttribute:(xmlAttrPtr)attr andClean:(BOOL)clean
{
	xmlNodePtr parent = attr->parent;
	
	// Update the surrounding prev/next pointers
	if (attr->prev == NULL)
	{
		if (attr->next == NULL)
		{
			parent->properties = NULL;
		}
		else
		{
			parent->properties = attr->next;
			attr->next->prev = NULL;
		}
	}
	else
	{
		if (attr->next == NULL)
		{
			attr->prev->next = NULL;
		}
		else
		{
			attr->prev->next = attr->next;
			attr->next->prev = attr->prev;
		}
	}
	
	if (clean)
	{
		// Nullify pointers
		attr->parent = NULL;
		attr->prev   = NULL;
		attr->next   = NULL;
		attr->ns     = NULL;
		if (attr->doc != NULL) [self stripDocPointersFromAttr:attr];
	}
}

/**
 * Detaches the given attribute from its parent node.
 * The attribute's surrounding prev/next pointers are properly updated to remove the attribute from the attr list.
 * Then the attribute's parent, prev, next and doc pointers are destroyed.
**/
+ (void)detachAttribute:(xmlAttrPtr)attr
{
	[self detachAttribute:attr andClean:YES];
}

/**
 * Removes and free's the given attribute from its parent node.
 * The attribute's surrounding prev/next pointers are properly updated to remove the attribute from the attr list.
**/
+ (void)removeAttribute:(xmlAttrPtr)attr
{
	DDXMLCheckAndSetErrorHandlerForCurrentThread();
	
#if DDXML_DEBUG_MEMORY_ISSUES
	MarkZombies(attr);
#endif
	
	// We perform a bit of optimization here.
	// No need to bother nullifying pointers since we're about to free the node anyway.
	[self detachAttribute:attr andClean:NO];
	
	xmlFreeProp(attr);
}

/**
 * Removes and frees all attributes from the given node.
 * Upon return, the given node's properties pointer is NULL.
**/
+ (void)removeAllAttributesFromNode:(xmlNodePtr)node
{
	DDXMLCheckAndSetErrorHandlerForCurrentThread();
	
	xmlAttrPtr attr = node->properties;
	while (attr != NULL)
	{
		xmlAttrPtr nextAttr = attr->next;
		
	#if DDXML_DEBUG_MEMORY_ISSUES
		MarkZombies(attr);
	#endif
		
		xmlFreeProp(attr);
		attr = nextAttr;
	}
	
	node->properties = NULL;
}

/**
 * Detaches the given child from its parent.
 * The child's surrounding prev/next pointers are properly updated to remove the child from the node's children list.
 * Then, if the clean flag is YES, the child's parent, prev, next and doc pointers are set to null.
**/
+ (void)detachChild:(xmlNodePtr)child andClean:(BOOL)clean andFixNamespaces:(BOOL)fixNamespaces
{
	xmlNodePtr parent = child->parent;
	
	// Update the surrounding prev/next pointers
	if (child->prev == NULL)
	{
		if (child->next == NULL)
		{
			parent->children = NULL;
			parent->last = NULL;
		}
		else
		{
			parent->children = child->next;
			child->next->prev = NULL;
		}
	}
	else
	{
		if (child->next == NULL)
		{
			parent->last = child->prev;
			child->prev->next = NULL;
		}
		else
		{
			child->prev->next = child->next;
			child->next->prev = child->prev;
		}
	}
	
	if (fixNamespaces)
	{
		// Fix namesapces (namespace references that now point outside tree)
		// Note: This must be done before we nullify pointers so we can search up the tree.
		[self recursiveFixDefaultNamespacesInNode:child withNewRoot:child];
	}
	if (clean)
	{
		// Nullify pointers
		child->parent = NULL;
		child->prev   = NULL;
		child->next   = NULL;
		if (child->doc != NULL) [self recursiveStripDocPointersFromNode:child];
	}
}

/**
 * Detaches the given child from its parent.
 * The child's surrounding prev/next pointers are properly updated to remove the child from the node's children list.
 * Then the child's parent, prev, next and doc pointers are set to null.
**/
+ (void)detachChild:(xmlNodePtr)child
{
	[self detachChild:child andClean:YES andFixNamespaces:YES];
}

/**
 * Removes the given child from its parent node.
 * The child's surrounding prev/next pointers are properly updated to remove the child from the node's children list.
 * Then the child is recursively freed if it's no longer being referenced.
 * Otherwise, it's parent, prev, next and doc pointers are destroyed.
 * 
 * During the recursive free, subnodes still being referenced are properly handled.
**/
+ (void)removeChild:(xmlNodePtr)child
{
	DDXMLCheckAndSetErrorHandlerForCurrentThread();
	
#if DDXML_DEBUG_MEMORY_ISSUES
	RecursiveMarkZombiesFromNode(child);
#endif
	
	// We perform a bit of optimization here.
	// No need to bother nullifying pointers since we're about to free the node anyway.
	[self detachChild:child andClean:NO andFixNamespaces:NO];
	
	xmlFreeNode(child);
}

/**
 * Removes all children from the given node.
 * All children are either recursively freed, or their parent, prev, next and doc pointers are properly destroyed.
 * Upon return, the given node's children pointer is NULL.
 * 
 * During the recursive free, subnodes still being referenced are properly handled.
**/
+ (void)removeAllChildrenFromNode:(xmlNodePtr)node
{
	DDXMLCheckAndSetErrorHandlerForCurrentThread();
	
	xmlNodePtr child = node->children;
	while (child != NULL)
	{
		xmlNodePtr nextChild = child->next;
		
#if DDXML_DEBUG_MEMORY_ISSUES
		RecursiveMarkZombiesFromNode(child);
#endif /* DDXML_DEBUG_MEMORY_ISSUES */
		
		xmlFreeNode(child);
		child = nextChild;
	}
	
	node->children = NULL;
	node->last = NULL;
}

/**
 * Returns the last error encountered by libxml.
 * Errors are caught in the DDXMLNodeErrorHandler method within KissXML+Private.
**/
+ (NSError *)lastError
{
	NSMutableDictionary *threadDictionary = [[NSThread currentThread] threadDictionary];
	return [threadDictionary objectForKey:DDXMLLastErrorKey];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Zombie Tracking
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#if DDXML_DEBUG_MEMORY_ISSUES

// What is zombie tracking and how does it work?
// 
// It is all explained in full detail here:
// https://github.com/robbiehanson/KissXML/wiki/MemoryManagementThreadSafety
// 
// But here's a quick overview in case you're on a plane right now
// (and the plane doesn't have internet access, or charges some ridiculous amount and you don't want to pay for it.)
// 
// <starbucks>
//   <latte/>
//   <cappuchino/>
// </starbucks>
// 
// You have a reference to the latte node, and you release/dealloc the starbucks node. Uh oh!
// The latte node is now a zombie, since the xmlNode it was pointing to (wrapping) is now gone.
// If you attempt to read info from the latte node, you might get a crash.
// Or you might get junk results.
// And if you attempt to write info to the latte node, you might just wind up with some ugly heap corruption.
// And if this happens, well.. it's a huge P.I.T.A to track down.
// 
// But I've been there before. And I feel your pain. That's where this debug option comes in.
// 
// The debugging option keeps a dictionary where the keys are the xml pointers (xmlNodePtr, xmlAttrPtr, etc),
// and the values are mutable arrays. Any wrapper objects (DDXMLElement, DDXMLNode, etc) get added to the
// mutable array for which the wrapper is pointing.
// 
// If the xml (xmlNodePtr, xmlAttrPtr, etc) is to be freed, it first removes its key from the dictionary,
// and in doing so destroys any associated mutable array.
// 
// So a zombie check ensures that the xml structure the wrapper is referring to hasn't been freed.
// If it has an exception is thrown to help track down the problem.
// 
// In other words, if you try to read info from the latte node, or attempt to alter the latte node
// (after you release/dealloc starbucks), you'll immediately get a helpful exception.
// (Goodbye junk values and heap corruption.)
// 
// This is helpful in debugging, as it is sometimes easy to forget about the memory rules of the xml heirarchy.
// Or simply due to combinations of passing subelements around and using asynchronous operations.


static void RecursiveMarkZombiesFromNode(xmlNodePtr node)
{
	// This method only exists if DDXML_DEBUG_MEMORY_ISSUES is enabled.
	
	// Mark attributes
	xmlAttrPtr attr = node->properties;
	while (attr != NULL)
	{
		MarkZombies(attr);
		attr = attr->next;
	}
	
	// Mark namespaces
	xmlNsPtr ns = node->nsDef;
	while (ns != NULL)
	{
		MarkZombies(ns);
		ns = ns->next;
	}
	if (node->ns)
	{
		MarkZombies(node->ns);
	}
	
	// Recursively mark children
	xmlNodePtr child = node->children;
	while (child != NULL)
	{
		RecursiveMarkZombiesFromNode(child);
		child = child->next;
	}
	
	MarkZombies(node);
}

static void RecursiveMarkZombiesFromDoc(xmlDocPtr doc)
{
	// This method only exists if DDXML_DEBUG_MEMORY_ISSUES is enabled.
	
	xmlNodePtr child = doc->children;
	while (child != NULL)
	{
		RecursiveMarkZombiesFromNode(child);
		
		child = child->next;
	}
	
	MarkZombies(doc);
}

static void MarkZombies(void *xmlPtr)
{
	// This method only exists if DDXML_DEBUG_MEMORY_ISSUES is enabled.
	
	dispatch_async(zombieQueue, ^{
		
	//	NSLog(@"MarkZombies: %p", xmlPtr);
		
		CFDictionaryRemoveValue(zombieTracker, xmlPtr);
	});
}

static void MarkBirth(void *xmlPtr, DDXMLNode *wrapper)
{
	// This method only exists if DDXML_DEBUG_MEMORY_ISSUES is enabled.
	
	const void *value = (void *)wrapper;
	
	dispatch_async(zombieQueue, ^{
		
	//	NSLog(@"MarkBirth: %p, %p", xmlPtr, value);
		
		CFMutableArrayRef values = (CFMutableArrayRef)CFDictionaryGetValue(zombieTracker, xmlPtr);
		if (values == NULL)
		{
			values = CFArrayCreateMutable(NULL, /*MaxCapacity:*/0, /*ValueCallbacks:*/NULL);
			CFArrayAppendValue(values, value);
			
			CFDictionarySetValue(zombieTracker, xmlPtr, values);
			CFRelease(values);
		}
		else
		{
			CFArrayAppendValue(values, value);
		}
	});
}

static void MarkDeath(void *xmlPtr, DDXMLNode *wrapper)
{
	// This method only exists if DDXML_DEBUG_MEMORY_ISSUES is enabled.
	
	const void *value = (void *)wrapper;
	
	dispatch_async(zombieQueue, ^{
		
	//	NSLog(@"MarkDeath: %p, %p", xmlPtr, value);
		
		CFMutableArrayRef values = (CFMutableArrayRef)CFDictionaryGetValue(zombieTracker, xmlPtr);
		if (values)
		{
			CFRange range = CFRangeMake(0, CFArrayGetCount(values));
			CFIndex idx = CFArrayGetFirstIndexOfValue(values, range, value);
			if (idx >= 0)
			{
				CFArrayRemoveValueAtIndex(values, idx);
			}
		}
	});
}

BOOL DDXMLIsZombie(void *xmlPtr, DDXMLNode *wrapper)
{
	// This method only exists if DDXML_DEBUG_MEMORY_ISSUES is enabled.
	
	__block BOOL result;
	
	const void *value = (void *)wrapper;
	
	dispatch_sync(zombieQueue, ^{
		
		CFMutableArrayRef values = (CFMutableArrayRef)CFDictionaryGetValue(zombieTracker, xmlPtr);
		if (values)
		{
			CFRange range = CFRangeMake(0, CFArrayGetCount(values));
			CFIndex idx = CFArrayGetFirstIndexOfValue(values, range, value);
			
			result = (idx < 0);
		}
		else
		{
			result = YES;
		}
	});
	
	return result;
}

#endif

@end
