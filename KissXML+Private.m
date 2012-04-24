//
//  DDXMLPrivate_.m
//  KissXML
//
//  Created by Keith Duncan on 07/04/2012.
//  Copyright (c) 2012 Realmac Software. All rights reserved.
//

#import "KissXML+Private.h"

#import <libxml/tree.h>

#import "KissXML-Constants.h"

NSString *const DDXMLLastErrorKey = @"com.realmacsoftware.kissxml.lasterror";
NSString *const DDXMLErrorFunctionIsSetKey = @"com.realmacsoftware.kissxml.errorfunctionisset";

static void DDXMLNodeErrorHandler(void *userData, xmlErrorPtr error)
{
	// This method is called by libxml when an error occurs.
	// We register for this error in the initialize method below.
	
	// Extract error message and store in the current thread's dictionary.
	// This ensures thread safey, and easy access for all other DDXML classes.
	
	NSMutableDictionary *threadDictionary = [[NSThread currentThread] threadDictionary];
	
	if (error == NULL)
	{
		[threadDictionary removeObjectForKey:DDXMLLastErrorKey];
		return;
	}
	
	int errorObjectCode = error->code;
	NSString *errorObjectDescription = [[NSString stringWithFormat:@"%s", error->message] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	
	NSDictionary *errorObjectInfo = [NSDictionary dictionaryWithObjectsAndKeys:
									 errorObjectDescription, NSLocalizedDescriptionKey,
									 nil];
	NSError *errorObject = [NSError errorWithDomain:DDXMLBundleIdentifier code:errorObjectCode userInfo:errorObjectInfo];
	
	[threadDictionary setObject:errorObject forKey:DDXMLLastErrorKey];
}

void DDXMLCheckAndSetErrorHandlerForCurrentThread(void)
{
	NSMutableDictionary *threadDictionary = [[NSThread currentThread] threadDictionary];
	if ([threadDictionary objectForKey:DDXMLErrorFunctionIsSetKey] != nil) {
		return;
	}
	
	initGenericErrorDefaultFunc(NULL);
	xmlSetStructuredErrorFunc(NULL, DDXMLNodeErrorHandler);
	
	[threadDictionary setObject:[NSNumber numberWithBool:YES] forKey:DDXMLErrorFunctionIsSetKey];
}
