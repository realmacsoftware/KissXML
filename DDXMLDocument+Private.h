//
//  DDXMLDocument+KissXMLPrivate.h
//  KissXML
//
//  Created by Keith Duncan on 14/04/2012.
//  Copyright (c) 2012 Realmac Software. All rights reserved.
//

#import "DDXMLDocument.h"

#import "KissXML+Private.h"

@interface DDXMLDocument (KissXMLPrivate)

+ (id)nodeWithDocPrimitive:(xmlDocPtr)doc owner:(DDXMLNode *)owner;
- (id)initWithDocPrimitive:(xmlDocPtr)doc owner:(DDXMLNode *)owner;

@end
