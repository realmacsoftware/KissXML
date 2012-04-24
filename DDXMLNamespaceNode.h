//
//  DDXMLNamespaceNode.h
//  KissXML
//
//  Created by Keith Duncan on 14/04/2012.
//  Copyright (c) 2012 Realmac Software. All rights reserved.
//

#import "DDXMLNode.h"
#import "DDXMLNode+Private.h"

@interface DDXMLNamespaceNode : DDXMLNode
{
	// The xmlNsPtr type doesn't store a reference to it's parent.
	// This is here to fix the problem, and make this class more compatible with the NSXML classes.
	xmlNodePtr nsParentPtr;
}

+ (id)nodeWithNsPrimitive:(xmlNsPtr)ns nsParent:(xmlNodePtr)parent owner:(DDXMLNode *)owner;
- (id)initWithNsPrimitive:(xmlNsPtr)ns nsParent:(xmlNodePtr)parent owner:(DDXMLNode *)owner;

- (xmlNodePtr)_nsParentPtr;
- (void)_setNsParentPtr:(xmlNodePtr)parentPtr;

// Overrides several methods in DDXMLNode

@end
