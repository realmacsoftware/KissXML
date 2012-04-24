//
//  DDXMLAttributeNode.m
//  KissXML
//
//  Created by Keith Duncan on 14/04/2012.
//  Copyright (c) 2012 Realmac Software. All rights reserved.
//

#import "DDXMLAttributeNode.h"

#import "KissXML+Private.h"

@implementation DDXMLAttributeNode

+ (id)nodeWithAttrPrimitive:(xmlAttrPtr)attr owner:(DDXMLNode *)owner
{
	return [[[DDXMLAttributeNode alloc] initWithAttrPrimitive:attr owner:owner] autorelease];
}

- (id)initWithAttrPrimitive:(xmlAttrPtr)attr owner:(DDXMLNode *)inOwner
{
	self = [super initWithPrimitive:(xmlKindPtr)attr owner:inOwner];
	return self;
}

+ (id)nodeWithPrimitive:(xmlKindPtr)kindPtr owner:(DDXMLNode *)owner
{
	// Promote initializers which use proper parameter types to enable compiler to catch more mistakes.
	NSAssert(NO, @"Use nodeWithAttrPrimitive:nsParent:owner:");
	
	return nil;
}

- (id)initWithPrimitive:(xmlKindPtr)kindPtr owner:(DDXMLNode *)inOwner
{
	// Promote initializers which use proper parameter types to enable compiler to catch more mistakes.
	NSAssert(NO, @"Use initWithAttrPrimitive:nsParent:owner:");
	
	[self release];
	return nil;
}

- (void)dealloc
{
	if (attrNsPtr) xmlFreeNs(attrNsPtr);
	[super dealloc];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Properties
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSString *)name
{
	DDXMLNotZombieAssert();
	
	xmlAttrPtr attr = (xmlAttrPtr)genericPtr;
	
	const xmlChar *xmlName = attr->name;
	if (xmlName == NULL)
	{
		return nil;
	}
	
	NSString *name = [NSString stringWithUTF8String:(const char *)xmlName];
	
	NSRange range = [name rangeOfString:@":"];
	if (range.length == 0)
	{
		if (attr->ns && attr->ns->prefix)
		{
			return [NSString stringWithFormat:@"%s:%@", attr->ns->prefix, name];
		}
	}
	
	return name;
}

- (void)setStringValue:(NSString *)string
{
	DDXMLCheckAndSetErrorHandlerForCurrentThread();
	
	DDXMLNotZombieAssert();
	
	xmlAttrPtr attr = (xmlAttrPtr)genericPtr;
	
	if (attr->children != NULL)
	{
		xmlChar *escapedString = xmlEncodeSpecialChars(attr->doc, (const xmlChar *)[string UTF8String]);
		xmlNodeSetContent((xmlNodePtr)attr, escapedString);
		xmlFree(escapedString);
	}
	else
	{
		xmlNodePtr text = xmlNewText((const xmlChar *)[string UTF8String]);
		attr->children = text;
	}
}

- (NSString *)stringValue
{
	DDXMLNotZombieAssert();
	
	xmlAttrPtr attr = (xmlAttrPtr)genericPtr;
	
	if (attr->children != NULL)
	{
		return [NSString stringWithUTF8String:(const char *)attr->children->content];
	}
	
	return nil;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Tree Navigation
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

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
	DDXMLCheckAndSetErrorHandlerForCurrentThread();
	
	DDXMLNotZombieAssert();
	
	xmlAttrPtr attr = (xmlAttrPtr)genericPtr;
	
	if (attr->parent != NULL)
	{
		// If this attribute is associated with a namespace,
		// then we need to copy the namespace in order to maintain the association.
		// 
		// Remember: attr->ns cannot be an owner of an allocated namespaces,
		//           so we need to use DDXMLAttributeNode's attrNsPtr.
		
		if (attr->ns && (attr->ns != attrNsPtr))
		{
			attrNsPtr = xmlNewNs(NULL, attr->ns->href, attr->ns->prefix);
		}
		
		[[self class] detachAttribute:attr];
		
		if (attrNsPtr)
		{
			attr->ns = attrNsPtr;
		}
		
		[owner release];
		owner = nil;
	}
}

- (xmlStdPtr)_XPathPreProcess:(NSMutableString *)result
{
	// This is a private/internal method
	
	// Note: DDXMLNamespaceNode overrides this method
	// Note: DDXMLAttributeNode overrides this method
	
	xmlAttrPtr attr = (xmlAttrPtr)genericPtr;
	xmlStdPtr parent = (xmlStdPtr)attr->parent;
	
	if (parent == NULL)
		[result appendFormat:@"@%@", [self name]];
	else
		[result appendFormat:@"/@%@", [self name]];
	
	return parent;
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark QNames
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)setURI:(NSString *)URI
{
	DDXMLCheckAndSetErrorHandlerForCurrentThread();
	
	DDXMLNotZombieAssert();
	
	// An attribute can only have a single namespace attached to it.
	// In addition, this namespace can only be accessed via the URI method.
	// There is no way, within the API, to get a DDXMLNode wrapper for the attribute's namespace.
	
	// Remember: attr->ns is simply a pointer to a namespace owned by somebody else.
	//           Unless that points to our attrNsPtr (defined in DDXMLAttributeNode) we cannot free it.
	
	if (attrNsPtr != NULL)
	{
		xmlFreeNs(attrNsPtr);
		attrNsPtr = NULL;
	}
	
	xmlAttrPtr attr = (xmlAttrPtr)genericPtr;
	attr->ns = NULL;
	
	if (URI)
	{
		// If there's a namespace defined further up the tree with this URI,
		// then we want attr->ns to point to it.
		
		const xmlChar *uri = (const xmlChar *)[URI UTF8String];
		
		xmlNodePtr parent = attr->parent;
		while (parent)
		{
			xmlNsPtr ns = parent->nsDef;
			while (ns)
			{
				if (xmlStrEqual(ns->href, uri))
				{
					attr->ns = ns;
					return;
				}
				
				ns = ns->next;
			}
			
			parent = parent->parent;
		}
		
		// There is no namespace further up the tree with this URI.
		// We'll have to create it ourself...
		// 
		// Remember: The attr->ns pointer is not allowed to have direct ownership.
		
		attrNsPtr = xmlNewNs(NULL, uri, NULL);
		attr->ns = attrNsPtr;
	}
}

- (NSString *)URI
{
	DDXMLCheckAndSetErrorHandlerForCurrentThread();
	
	DDXMLNotZombieAssert();
	
	xmlAttrPtr attr = (xmlAttrPtr)genericPtr;
	if (attr->ns != NULL)
	{
		if (attr->ns->href != NULL)
		{
			return [NSString stringWithUTF8String:((const char *)attr->ns->href)];
		}
	}
	
	// The attribute doesn't explicitly have a namespace.
	// But if the attribute is something like animal:duck='quack', then we should look for the URI for 'animal'.
	// 
	// Note: [self prefix] returns an empty string if there is no prefix. (Not nil)
	
	NSString *prefix = [self prefix];
	if ([prefix length] > 0)
	{
		xmlNsPtr ns = xmlSearchNs(attr->doc, attr->parent, (const xmlChar *)[prefix UTF8String]);
		if (ns && ns->href)
		{
			return [NSString stringWithUTF8String:((const char *)ns->href)];
		}
	}
	
	return nil;
}

@end
