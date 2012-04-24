//
//  DDXMLNode+Private.h
//  KissXML
//
//  Created by Damien DeVille on 10/01/2012.
//  Copyright (c) 2012 Damien DeVille. All rights reserved.
//

#import "DDXMLNode.h"

#import <libxml/tree.h>

/**
 * DDXMLNode can represent several underlying types, such as xmlNodePtr, xmlDocPtr, xmlAttrPtr, xmlNsPtr, etc.
 * All of these are pointers to structures, and all of those structures start with a pointer, and a type.
 * The xmlKind struct is used as a generic structure, and a stepping stone.
 * We use it to check the type of a structure, and then perform the appropriate cast.
 * 
 * For example:
 * if(genericPtr->type == XML_ATTRIBUTE_NODE)
 * {
 *     xmlAttrPtr attr = (xmlAttrPtr)genericPtr;
 *     // Do something with attr
 * }
**/
struct _xmlKind {
	void *ignore;
	xmlElementType type;
};
typedef struct _xmlKind *xmlKindPtr;

/**
 * Most xml types all start with this standard structure. In fact, all do except the xmlNsPtr.
 * We will occasionally take advantage of this to simplify code when the code wouldn't vary from type to type.
 * Obviously, you cannnot cast a xmlNsPtr to a xmlStdPtr.
**/
struct _xmlStd {
	void * _private;
	xmlElementType type;
	const xmlChar *name;
	struct _xmlNode *children;
	struct _xmlNode *last;
	struct _xmlNode *parent;
	struct _xmlStd *next;
	struct _xmlStd *prev;
	struct _xmlDoc *doc;
};
typedef struct _xmlStd *xmlStdPtr;


static inline BOOL IsXmlAttrPtr(void *kindPtr)
{
	return ((xmlKindPtr)kindPtr)->type == XML_ATTRIBUTE_NODE;
}

static inline BOOL IsXmlNodePtr(void *kindPtr)
{
	switch (((xmlKindPtr)kindPtr)->type)
	{
		case XML_ELEMENT_NODE:
		case XML_PI_NODE:
		case XML_COMMENT_NODE:
		case XML_TEXT_NODE:
		case XML_CDATA_SECTION_NODE:
		{
			return YES;
		}
		default:
		{
			return NO;
		}
	}
}

static inline BOOL IsXmlDocPtr(void *kindPtr)
{
	return (((xmlKindPtr)kindPtr)->type == XML_DOCUMENT_NODE || ((xmlKindPtr)kindPtr)->type == XML_HTML_DOCUMENT_NODE);
}

static inline BOOL IsXmlDtdPtr(void *kindPtr)
{
	return ((xmlKindPtr)kindPtr)->type == XML_DTD_NODE;
}

static inline BOOL IsXmlNsPtr(void *kindPtr)
{
	return ((xmlKindPtr)kindPtr)->type == XML_NAMESPACE_DECL;
}

/*!
	
 */
extern BOOL DDXMLIsZombie(void *xmlPtr, DDXMLNode *wrapper);

/*!
	
 */
@interface DDXMLNode () {
 @protected
	// Every DDXML object is simply a wrapper around an underlying libxml node
	struct _xmlKind *genericPtr;
	
	// Every libxml node resides somewhere within an xml tree heirarchy.
	// We cannot free the tree heirarchy until all referencing nodes have been released.
	// So all nodes retain a reference to the node that created them,
	// and when the last reference is released the tree gets freed.
	DDXMLNode *owner;
}

@end

@interface DDXMLNode (KissXMLPrivate)

+ (NSError *)lastError;

+ (id)nodeWithUnknownPrimitive:(xmlKindPtr)kindPtr owner:(DDXMLNode *)owner;

+ (id)nodeWithPrimitive:(xmlKindPtr)kindPtr owner:(DDXMLNode *)owner;
- (id)initWithPrimitive:(xmlKindPtr)kindPtr owner:(DDXMLNode *)owner;

+ (void)getHasPrefix:(BOOL *)hasPrefixPtr localName:(NSString **)localNamePtr forName:(NSString *)name;
+ (void)getPrefix:(NSString **)prefixPtr localName:(NSString **)localNamePtr forName:(NSString *)name;

+ (void)recursiveStripDocPointersFromNode:(xmlNodePtr)node;

+ (void)detachNamespace:(xmlNsPtr)ns fromNode:(xmlNodePtr)node;
+ (void)removeNamespace:(xmlNsPtr)ns fromNode:(xmlNodePtr)node;
+ (void)removeAllNamespacesFromNode:(xmlNodePtr)node;

+ (void)detachAttribute:(xmlAttrPtr)attr andClean:(BOOL)clean;
+ (void)detachAttribute:(xmlAttrPtr)attr;
+ (void)removeAttribute:(xmlAttrPtr)attr;
+ (void)removeAllAttributesFromNode:(xmlNodePtr)node;

+ (void)detachChild:(xmlNodePtr)child andClean:(BOOL)clean andFixNamespaces:(BOOL)fixNamespaces;
+ (void)detachChild:(xmlNodePtr)child;
+ (void)removeChild:(xmlNodePtr)child;
+ (void)removeAllChildrenFromNode:(xmlNodePtr)node;

- (BOOL)hasParent;

@end
