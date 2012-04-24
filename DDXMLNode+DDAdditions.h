//
//  DDXMLNode+DDAdditions.h
//  KissXML
//
//  Created by Keith Duncan on 07/04/2012.
//  Copyright (c) 2012 Realmac Software. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "KissXML/KissXML.h"

/*!
	\brief
	Provides API parity with NSXML* combined with RMFoundation
 */
@interface DDXMLNode (DDAdditions)

- (NSString *)stringValueForXPath:(NSString *)XPath namespaceMap:(NSDictionary *)namespaceMap error:(NSError **)errorRef;

- (NSString *)XMLStringValueForXPath:(NSString *)XPath namespaceMap:(NSDictionary *)namespaceMap error:(NSError **)errorRef;

@end
