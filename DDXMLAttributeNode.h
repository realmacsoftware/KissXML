//
//  DDXMLAttributeNode.h
//  KissXML
//
//  Created by Keith Duncan on 14/04/2012.
//  Copyright (c) 2012 Realmac Software. All rights reserved.
//

#import "DDXMLNode.h"
#import "DDXMLNode+Private.h"

@interface DDXMLAttributeNode : DDXMLNode
{
	// The xmlAttrPtr type doesn't allow for ownership of a namespace.
	// 
	// In other types, such as xmlNodePtr:
	// - nsDef stores namespaces that are owned by the node (have been alloced by the node).
	// - ns is simply a pointer to the default namespace of the node, which may or may not reside in its own nsDef list.
	// 
	// The xmlAttrPtr only has a ns, it doesn't have a nsDef list.
	// Which completely makes sense really, since namespaces have to be defined elsewhere.
	// 
	// This is here to maintain compatibility with the NSXML classes,
	// where one can assign a namespace to an attribute independently.
	xmlNsPtr attrNsPtr;
}

+ (id)nodeWithAttrPrimitive:(xmlAttrPtr)attr owner:(DDXMLNode *)owner;
- (id)initWithAttrPrimitive:(xmlAttrPtr)attr owner:(DDXMLNode *)owner;

// Overrides several methods in DDXMLNode

@end
