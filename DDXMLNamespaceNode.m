//
//  DDXMLNamespaceNode.m
//  KissXML
//
//  Created by Keith Duncan on 14/04/2012.
//  Copyright (c) 2012 Realmac Software. All rights reserved.
//

#import "DDXMLNamespaceNode.h"

#import "DDXMLNode+Private.h"
#import "DDXMLDocument+Private.h"

@implementation DDXMLNamespaceNode

/**
 * Returns a DDXML wrapper object for the given primitive node.
 * The given node MUST be non-NULL and of the proper type.
 **/
+ (id)nodeWithNsPrimitive:(xmlNsPtr)ns nsParent:(xmlNodePtr)parent owner:(DDXMLNode *)owner
{
	return [[[DDXMLNamespaceNode alloc] initWithNsPrimitive:ns nsParent:parent owner:owner] autorelease];
}

/**
 * Returns a DDXML wrapper object for the given primitive node.
 * The given node MUST be non-NULL and of the proper type.
 **/
- (id)initWithNsPrimitive:(xmlNsPtr)ns nsParent:(xmlNodePtr)parent owner:(DDXMLNode *)inOwner
{
	if ((self = [super initWithPrimitive:(xmlKindPtr)ns owner:inOwner]))
	{
		nsParentPtr = parent;
	}
	return self;
}

+ (id)nodeWithPrimitive:(xmlKindPtr)kindPtr owner:(DDXMLNode *)owner
{
	// Promote initializers which use proper parameter types to enable compiler to catch more mistakes.
	NSAssert(NO, @"Use nodeWithNsPrimitive:nsParent:owner:");
	
	return nil;
}

- (id)initWithPrimitive:(xmlKindPtr)kindPtr owner:(DDXMLNode *)inOwner
{
	// Promote initializers which use proper parameter types to enable compiler to catch more mistakes.
	NSAssert(NO, @"Use initWithNsPrimitive:nsParent:owner:");
	
	[self release];
	return nil;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Properties
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)setName:(NSString *)name
{
	DDXMLCheckAndSetErrorHandlerForCurrentThread();
	
	DDXMLNotZombieAssert();
	
	xmlNsPtr ns = (xmlNsPtr)genericPtr;
	
	xmlFree((xmlChar *)ns->prefix);
	ns->prefix = xmlStrdup((const xmlChar *)[name UTF8String]);
}

- (NSString *)name
{
	DDXMLNotZombieAssert();
	
	xmlNsPtr ns = (xmlNsPtr)genericPtr;
	if (ns->prefix != NULL)
		return [NSString stringWithUTF8String:((const char*)ns->prefix)];
	else
		return @"";
}

- (void)setStringValue:(NSString *)string
{
	DDXMLCheckAndSetErrorHandlerForCurrentThread();
	
	DDXMLNotZombieAssert();
	
	xmlNsPtr ns = (xmlNsPtr)genericPtr;
	
	xmlFree((xmlChar *)ns->href);
	ns->href = xmlEncodeSpecialChars(NULL, (const xmlChar *)[string UTF8String]);
}

- (NSString *)stringValue
{
	DDXMLNotZombieAssert();
	
	return [NSString stringWithUTF8String:((const char *)((xmlNsPtr)genericPtr)->href)];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Tree Navigation
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSUInteger)index
{
	DDXMLNotZombieAssert();
	
	xmlNsPtr ns = (xmlNsPtr)genericPtr;
	
	// The xmlNsPtr has no prev pointer, so we have to search from the parent
	
	if (nsParentPtr == NULL)
	{
		return 0;
	}
	
	NSUInteger result = 0;
	
	xmlNsPtr currentNs = nsParentPtr->nsDef;
	while (currentNs != NULL)
	{
		if (currentNs == ns)
		{
			return result;
		}
		result++;
		currentNs = currentNs->next;
	}
	
	return 0; // Yes 0, not result, because ns wasn't found in list
}

- (NSUInteger)level
{
	DDXMLNotZombieAssert();
	
	NSUInteger result = 0;
	
	xmlNodePtr currentNode = nsParentPtr;
	while (currentNode != NULL)
	{
		result++;
		currentNode = currentNode->parent;
	}
	
	return result;
}

- (DDXMLDocument *)rootDocument
{
	DDXMLNotZombieAssert();
	
	xmlStdPtr node = (xmlStdPtr)nsParentPtr;
	
	if (node == NULL || node->doc == NULL)
		return nil;
	else
		return [DDXMLDocument nodeWithDocPrimitive:node->doc owner:self];
}

- (DDXMLNode *)parent
{
	DDXMLNotZombieAssert();
	
	if (nsParentPtr == NULL)
		return nil;
	else
		return [DDXMLNode nodeWithUnknownPrimitive:(xmlKindPtr)nsParentPtr owner:self];
}

- (NSUInteger)childCount
{
	DDXMLNotZombieAssert();
	
	return 0;
}

- (NSArray *)children
{
	DDXMLNotZombieAssert();
	
	return nil;
}

- (DDXMLNode *)childAtIndex:(NSUInteger)index
{
	DDXMLNotZombieAssert();
	
	return nil;
}

- (DDXMLNode *)previousSibling
{
	DDXMLNotZombieAssert();
	
	return nil;
}

- (DDXMLNode *)nextSibling
{
	DDXMLNotZombieAssert();
	
	return nil;
}

- (DDXMLNode *)previousNode
{
	DDXMLNotZombieAssert();
	
	return nil;
}

- (DDXMLNode *)nextNode
{
	DDXMLNotZombieAssert();
	
	return nil;
}

- (void)detach
{
	DDXMLNotZombieAssert();
	
	if (nsParentPtr != NULL)
	{
		[DDXMLNode detachNamespace:(xmlNsPtr)genericPtr fromNode:nsParentPtr];
		
		[owner release];
		owner = nil;
		
		nsParentPtr = NULL;
	}
}

- (xmlStdPtr)_XPathPreProcess:(NSMutableString *)result
{
	// This is a private/internal method
	
	xmlStdPtr parent = (xmlStdPtr)nsParentPtr;
	
	if (parent == NULL)
		[result appendFormat:@"namespace::%@", [self name]];
	else
		[result appendFormat:@"/namespace::%@", [self name]];
	
	return parent;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark QNames
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)localName
{
	DDXMLNotZombieAssert();
	
	// Strangely enough, the localName of a namespace is the prefix, and the prefix is an empty string
	xmlNsPtr ns = (xmlNsPtr)genericPtr;
	if (ns->prefix != NULL)
		return [NSString stringWithUTF8String:((const char *)ns->prefix)];
	else
		return @"";
}

- (NSString *)prefix
{
	DDXMLNotZombieAssert();
	
	// Strangely enough, the localName of a namespace is the prefix, and the prefix is an empty string
	return @"";
}

- (void)setURI:(NSString *)URI
{
	DDXMLNotZombieAssert();
	
	// Do nothing
}

- (NSString *)URI
{
	DDXMLNotZombieAssert();
	
	return nil;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Private API
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (BOOL)hasParent
{
	// This is a private/internal method
	
	return (nsParentPtr != NULL);
}

- (xmlNodePtr)_nsParentPtr
{
	// This is a private/internal method
	
	return nsParentPtr;
}

- (void)_setNsParentPtr:(xmlNodePtr)parentPtr
{
	// This is a private/internal method
	
	nsParentPtr = parentPtr;
}

@end
