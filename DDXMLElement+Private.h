//
//  DDXMLElement+KissXMLPrivate.h
//  KissXML
//
//  Created by Keith Duncan on 14/04/2012.
//  Copyright (c) 2012 Realmac Software. All rights reserved.
//

#import "DDXMLElement.h"

#import "KissXML+Private.h"

@interface DDXMLElement (KissXMLPrivate)

+ (id)nodeWithElementPrimitive:(xmlNodePtr)node owner:(DDXMLNode *)owner;
- (id)initWithElementPrimitive:(xmlNodePtr)node owner:(DDXMLNode *)owner;

- (DDXMLNode *)_recursiveResolveNamespaceForPrefix:(NSString *)prefix atNode:(xmlNodePtr)nodePtr;
- (NSString *)_recursiveResolvePrefixForURI:(NSString *)uri atNode:(xmlNodePtr)nodePtr;

@end
