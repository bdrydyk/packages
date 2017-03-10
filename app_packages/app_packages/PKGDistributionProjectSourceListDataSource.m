/*
 Copyright (c) 2017, Stephane Sudre
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 - Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 - Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 - Neither the name of the WhiteBox nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "PKGDistributionProjectSourceListDataSource.h"

#import "PKGDistributionProjectSourceListForest.h"
#import "PKGDistributionProjectSourceListTreeNode.h"
#import "PKGDistributionProjectSourceListGroupItem.h"
#import "PKGDistributionProjectSourceListPackageComponentItem.h"

#import "NSOutlineView+Selection.h"

#import "NSArray+UniqueName.h"

#import "PKGProjectTemplateDefaultValuesSettings.h"

#import "PKGOwnershipAndReferenceStyleViewController.h"
#import "PKGApplicationPreferences.h"

#import "PKGOwnershipAndReferenceStylePanel.h"

#import "PKGArchive.h"

@interface PKGPackagesImportPanelDelegate : NSObject<NSOpenSavePanelDelegate>
{
	NSFileManager * _fileManager;
}

	@property NSArray * importedPackageComponents;
	@property (weak) id<PKGFilePathConverter> filePathConverter;

@end

@implementation PKGPackagesImportPanelDelegate

- (instancetype)init
{
	self=[super init];
	
	if (self!=nil)
	{
		_fileManager=[NSFileManager defaultManager];
	}
	
	return self;
}

#pragma mark - NSOpenSavePanelDelegate

- (BOOL)panel:(NSOpenPanel *)inPanel shouldEnableURL:(NSURL *)inURL
{
	if (inURL.isFileURL==NO)
		return NO;
	
	NSString * tAbsolutePath=inURL.path;
	
	if (tAbsolutePath==nil)
		return NO;
	
	BOOL isDirectory;
	
	[_fileManager fileExistsAtPath:tAbsolutePath isDirectory:&isDirectory];
	
	if (isDirectory==YES)
		return YES;
	
	// Check whether the package has not been imported yet.
	
	if ([self.importedPackageComponents indexOfObjectPassingTest:^BOOL(PKGPackageComponent *bPackageComponent,NSUInteger bIndex,BOOL * bOutStop){
		
		return ([[self.filePathConverter absolutePathForFilePath:bPackageComponent.importPath] caseInsensitiveCompare:tAbsolutePath]==NSOrderedSame);
		
	}]!=NSNotFound)
		return NO;
	
	// Check whether it's a flat package or not
	
	PKGArchive * tPackageArchive=[PKGArchive archiveAtPath:tAbsolutePath];
	
	return [tPackageArchive isFlatPackage];
}

@end

@interface PKGDistributionProjectSourceListDataSource ()
{
	PKGDistributionProjectSourceListForest * _forest;
	
	PKGPackagesImportPanelDelegate * _importPanelDelegate;
}

- (void)outlineView:(NSOutlineView *)inOutlineView addPackageComponent:(PKGPackageComponent *)inPackageComponent;
- (void)outlineView:(NSOutlineView *)inOutlineView addPackageComponents:(NSArray *)inPackageComponents;

@end

@implementation PKGDistributionProjectSourceListDataSource

+ (NSArray *)supportedDraggedTypes
{
	return @[NSFilenamesPboardType];
}

- (void)setPackageComponents:(NSMutableArray *)inPackageComponents
{
	if (_packageComponents!=inPackageComponents)
	{
		_packageComponents=inPackageComponents;
		
		_forest=[[PKGDistributionProjectSourceListForest alloc] initWithPackageComponents:inPackageComponents];
	}
}

#pragma mark - NSOutlineViewDataSource

- (NSInteger)outlineView:(NSOutlineView *)inOutlineView numberOfChildrenOfItem:(PKGTreeNode *)inTreeNode
{
	if (inTreeNode==nil)
		return _forest.rootNodes.count;
	
	return inTreeNode.numberOfChildren;
}

- (id)outlineView:(NSOutlineView *)inOutlineView child:(NSInteger)inIndex ofItem:(PKGTreeNode *)inTreeNode
{
	if (inTreeNode==nil)
		return _forest.rootNodes[inIndex];
	
	return [inTreeNode descendantNodeAtIndex:inIndex];
}

- (BOOL)outlineView:(NSOutlineView *)inOutlineView isItemExpandable:(PKGTreeNode *)inTreeNode
{
	return ([inTreeNode isLeaf]==NO);
}

#pragma mark - Drag and Drop support

- (BOOL)outlineView:(NSOutlineView *)inOutlineView writeItems:(NSArray*)inItems toPasteboard:(NSPasteboard*)inPasteboard
{
	/*for(PKGPayloadTreeNode * tTreeNode in inItems)
	{
		if ([tTreeNode isTemplateNode]==YES)
			return NO;
	}
	
	_internalDragData=[PKGTreeNode minimumNodeCoverFromNodesInArray:inItems];	// A COMPLETER (Find how to empty it when the drag and drop is done)
	
	[inPasteboard declareTypes:@[PKGPayloadItemsInternalPboardType,PKGPayloadItemsPboardType] owner:self];		// Make the external drag a promised case since it will be less usual IMHO
	
	[inPasteboard setData:[NSData data] forType:PKGPayloadItemsInternalPboardType];*/
	
	return NO;
}

- (NSDragOperation)outlineView:(NSOutlineView*)inOutlineView validateDrop:(id <NSDraggingInfo>)info proposedItem:(PKGPayloadTreeNode *)inProposedTreeNode proposedChildIndex:(NSInteger)inChildIndex
{
	if (inProposedTreeNode==nil)
		return NSDragOperationNone;
	
	NSPasteboard * tPasteBoard=[info draggingPasteboard];
	
	if ([tPasteBoard availableTypeFromArray:@[NSFilenamesPboardType]]!=nil)
	{
		NSArray * tArray=(NSArray *) [tPasteBoard propertyListForType:NSFilenamesPboardType];
		
		if (tArray==nil || [tArray isKindOfClass:NSArray.class]==NO || tArray.count==0)
		{
			// We were provided invalid data
			
			// A COMPLETER
			
			return NSDragOperationNone;
		}
		
		NSArray * tAlreadyImportedPaths=[[self.packageComponents WB_filteredArrayUsingBlock:^BOOL(PKGPackageComponent * bPackageComponent,NSUInteger bIndex){
		
			return (bPackageComponent.type==PKGPackageComponentTypeImported);
		}] WB_arrayByMappingObjectsUsingBlock:^(PKGPackageComponent * bPackageComponent,NSUInteger bIndex){
		
			return [self.filePathConverter absolutePathForFilePath:bPackageComponent.importPath];
		}];
		
		if (tAlreadyImportedPaths==nil)
		{
			NSLog(@"Error when computing the list of paths for already imported packages");
		}
		
		for(NSString * tPath in tArray)
		{
			if ([tAlreadyImportedPaths containsObject:tPath]==YES)
				return NSDragOperationNone;
			
			PKGArchive * tArchive=[PKGArchive archiveAtPath:tPath];
			
			if ([tArchive isFlatPackage]==NO)
				return NSDragOperationNone;
		}
		
		[inOutlineView setDropItem:nil dropChildIndex:-1];
		
		return NSDragOperationCopy;
	}
	
	return NSDragOperationNone;
}

- (BOOL)outlineView:(NSOutlineView*)inOutlineView acceptDrop:(id <NSDraggingInfo>)info item:(PKGPayloadTreeNode *)inProposedTreeNode childIndex:(NSInteger)inChildIndex
{
	if (inOutlineView==nil)
		return NO;

	NSPasteboard * tPasteBoard=[info draggingPasteboard];
	
	// Filenames
	
	if ([tPasteBoard availableTypeFromArray:@[NSFilenamesPboardType]]!=nil)
	{
		NSArray * tArray=(NSArray *) [tPasteBoard propertyListForType:NSFilenamesPboardType];
		
		PKGOwnershipAndReferenceStylePanel * tPanel=[PKGOwnershipAndReferenceStylePanel ownershipAndReferenceStylePanel];
		
		tPanel.canChooseOwnerAndGroupOptions=NO;
		tPanel.referenceStyle=[PKGApplicationPreferences sharedPreferences].defaultFilePathReferenceStyle;
		
		[tPanel beginSheetModalForWindow:inOutlineView.window completionHandler:^(NSInteger bReturnCode){
			
			if (bReturnCode==PKGOwnershipAndReferenceStylePanelCancelButton)
				return;
			
			PKGFilePathType tFileType=tPanel.referenceStyle;
			
			__block NSMutableArray * tTemporaryComponents=[self.packageComponents mutableCopy];
			
			NSArray * tImportedPackageComponents=[tArray WB_arrayByMappingObjectsLenientlyUsingBlock:^PKGPackageComponent *(NSString * bImportPath, NSUInteger bIndex) {
				
				PKGFilePath * tFilePath=[self.filePathConverter filePathForAbsolutePath:bImportPath type:tFileType];
				
				if (tFilePath==nil)
				{
					// A COMPLETER
					
					return nil;
				}
				
				PKGPackageComponent * tPackageComponent=[PKGPackageComponent importedComponentWithFilePath:tFilePath];
				
				NSString * tName=[tTemporaryComponents uniqueNameWithBaseName:[bImportPath.lastPathComponent stringByDeletingPathExtension] usingNameExtractor:^NSString *(PKGPackageComponent * bPackageComponent, NSUInteger bIndex) {
					return bPackageComponent.packageSettings.name;
				}];
				
				if (tName!=nil)
					tPackageComponent.packageSettings.name=tName;
				
				[tTemporaryComponents addObject:tPackageComponent];
				
				return tPackageComponent;
			}];
			
			[self outlineView:inOutlineView addPackageComponents:tImportedPackageComponents];
		}];
		
		return YES;		// It may at the end not be accepted by the completion handler from the sheet
	}
	
	return NO;
}

#pragma mark -

- (void)addProjectPackageComponent:(NSOutlineView *)inOutlineView
{
	PKGPackageComponent * tProjectComponent=[PKGPackageComponent projectComponent];
	
	// Name
	
	NSString * tName=[self.packageComponents uniqueNameWithBaseName:NSLocalizedString(@"untitled package",@"No comment") usingNameExtractor:^NSString *(PKGPackageComponent *bPackageComponent,NSUInteger bIndex){
	
		return bPackageComponent.packageSettings.name;
	}];
	
	tProjectComponent.packageSettings.name=(tName==nil)? @"" : tName;
	
	// Identifier
	
	NSArray * tNameComponents=[tProjectComponent.packageSettings.name componentsSeparatedByString:@" "];
	
	NSString * tPackageIdentifier=[tNameComponents componentsJoinedByString:@"-"];
	if (tPackageIdentifier==nil)
		tPackageIdentifier=@"";
	
	NSString * tDefaultIdentifierPrefix=[[PKGProjectTemplateDefaultValuesSettings sharedSettings] valueForKey:PKGProjectTemplateCompanyIdentifierPrefixKey];
	
	if (tDefaultIdentifierPrefix!=nil)
	{
		NSString * tFormat=@"%@%@";
		
		if ([tDefaultIdentifierPrefix hasSuffix:@"."]==NO)
			tFormat=@"%@.%@";
		
		tPackageIdentifier=[NSString stringWithFormat:tFormat,tDefaultIdentifierPrefix,tPackageIdentifier];
	}
	
	tPackageIdentifier=[self.packageComponents uniqueNameWithBaseName:tPackageIdentifier format:@"%@-@lu" options:NSCaseInsensitiveSearch usingNameExtractor:^NSString *(PKGPackageComponent *bPackageComponent,NSUInteger bIndex){
		
		return bPackageComponent.packageSettings.identifier;
	}];
	
	tProjectComponent.packageSettings.identifier=(tPackageIdentifier==nil)? @"" : tPackageIdentifier;
	
	[self outlineView:inOutlineView addPackageComponent:tProjectComponent];
}

- (void)addReferencePackageComponent:(NSOutlineView *)inOutlineView
{
	PKGPackageComponent * tProjectComponent=[PKGPackageComponent referenceComponent];
	
	NSString * tName=[self.packageComponents uniqueNameWithBaseName:NSLocalizedString(@"untitled package",@"No comment") usingNameExtractor:^NSString *(PKGPackageComponent *bPackageComponent,NSUInteger bIndex){
		
		return bPackageComponent.packageSettings.name;
	}];
	
	tProjectComponent.packageSettings.name=(tName==nil)? @"" : tName;
	
	[self outlineView:inOutlineView addPackageComponent:tProjectComponent];
}

- (void)importPackageComponent:(NSOutlineView *)inOutlineView
{
	NSOpenPanel * tImportPanel=[NSOpenPanel openPanel];
	
	tImportPanel.resolvesAliases=YES;
	tImportPanel.canChooseFiles=YES;
	tImportPanel.allowsMultipleSelection=YES;
	tImportPanel.treatsFilePackagesAsDirectories=YES;
	tImportPanel.canCreateDirectories=NO;
	tImportPanel.prompt=NSLocalizedString(@"Import", @"");
	
	NSArray * tImportedPackageComponents=[self.packageComponents WB_filteredArrayUsingBlock:^BOOL(PKGPackageComponent * bPackageComponent, NSUInteger bIndex) {
		
		return (bPackageComponent.type==PKGPackageComponentTypeImported);
	}];
	
	_importPanelDelegate=[PKGPackagesImportPanelDelegate new];
	
	_importPanelDelegate.filePathConverter=self.filePathConverter;
	_importPanelDelegate.importedPackageComponents=tImportedPackageComponents;
	
	tImportPanel.delegate=_importPanelDelegate;
	
	__block PKGFilePathType tReferenceStyle=[PKGApplicationPreferences sharedPreferences].defaultFilePathReferenceStyle;
	
	PKGOwnershipAndReferenceStyleViewController * tOwnershipAndReferenceStyleViewController=[PKGOwnershipAndReferenceStyleViewController new];
	
	tOwnershipAndReferenceStyleViewController.canChooseOwnerAndGroupOptions=NO;
	tOwnershipAndReferenceStyleViewController.referenceStyle=tReferenceStyle;
	
	NSView * tAccessoryView=tOwnershipAndReferenceStyleViewController.view;
	
	tImportPanel.accessoryView=tAccessoryView;
	
	[tImportPanel beginSheetModalForWindow:inOutlineView.window completionHandler:^(NSInteger bResult){
		
		if (bResult!=NSFileHandlingPanelOKButton)
			return;
		
		PKGFilePathType tFileType=tOwnershipAndReferenceStyleViewController.referenceStyle;
		
		__block NSMutableArray * tTemporaryComponents=[NSMutableArray arrayWithArray:self.packageComponents];
		
		NSArray * tImportedPackageComponents=[tImportPanel.URLs WB_arrayByMappingObjectsLenientlyUsingBlock:^PKGPackageComponent *(NSURL * bImportURL, NSUInteger bIndex) {
			
			PKGFilePath * tFilePath=[self.filePathConverter filePathForAbsolutePath:bImportURL.path type:tFileType];
			
			if (tFilePath==nil)
			{
				// A COMPLETER
				
				return nil;
			}
			
			PKGPackageComponent * tPackageComponent=[PKGPackageComponent importedComponentWithFilePath:tFilePath];
			
			NSString * tName=[tTemporaryComponents uniqueNameWithBaseName:[bImportURL.path.lastPathComponent stringByDeletingPathExtension] usingNameExtractor:^NSString *(PKGPackageComponent * bPackageComponent, NSUInteger bIndex) {
				return bPackageComponent.packageSettings.name;
			}];
			
			tPackageComponent.packageSettings.name=tName;
			
			[tTemporaryComponents addObject:tPackageComponent];
			
			return tPackageComponent;
		}];
		
		[self outlineView:inOutlineView addPackageComponents:tImportedPackageComponents];
	}];
}

- (void)outlineView:(NSOutlineView *)inOutlineView addPackageComponent:(PKGPackageComponent *)inPackageComponent
{
	if (inPackageComponent==nil)
		return;
	
	[self outlineView:inOutlineView addPackageComponents:@[inPackageComponent]];
}

- (void)outlineView:(NSOutlineView *)inOutlineView addPackageComponents:(NSArray *)inPackageComponents
{
	if (inOutlineView==nil || inPackageComponents.count==0)
		return;
	
	NSMutableSet * tMutableSet=[NSMutableSet set];
	
	for(PKGPackageComponent * tPackageComponent in inPackageComponents)
	{
		if ([self.packageComponents containsObject:tPackageComponent]==YES)
		{
			// A COMPLETER
			
			continue;
		}

		[self.packageComponents addObject:tPackageComponent];
		
		[_forest addPackageComponent:tPackageComponent];
		
		[tMutableSet addObject:tPackageComponent];
	}
	
	if (tMutableSet.count==0)
		return;
	
	[self.delegate sourceListDataDidChange:self];
	
	// Post Notification
	
	// A COMPLETER
	
	[inOutlineView reloadData];
	
	NSMutableIndexSet * tMutableIndexSet=[NSMutableIndexSet indexSet];
	
	for(PKGPackageComponent * tPackageComponent in tMutableSet)
	{
		PKGDistributionProjectSourceListTreeNode * tTreeNode=[_forest treeNodeForPackageComponent:tPackageComponent];
	
		[inOutlineView expandItem:tTreeNode.parent];
	
		NSInteger tSelectedRow=(tTreeNode==nil) ? 0 : [inOutlineView rowForItem:tTreeNode];
	
		if (tSelectedRow==-1)
			tSelectedRow=0;
		
		[tMutableIndexSet addIndex:tSelectedRow];
	}
	
	[inOutlineView scrollRowToVisible:(tMutableIndexSet.firstIndex==NSNotFound) ? 0 : tMutableIndexSet.firstIndex];
	
	[inOutlineView selectRowIndexes:tMutableIndexSet byExtendingSelection:NO];
}

- (BOOL)outlineView:(NSOutlineView *)inOutlineView shouldRenamePackageComponent:(PKGDistributionProjectSourceListTreeNode *)inPackageComponentTreeNode as:(NSString *)inNewName
{
	if (inOutlineView==nil || inPackageComponentTreeNode==nil || inNewName==nil)
		return NO;
	
	PKGPackageComponent * tPackageComponent=((PKGDistributionProjectSourceListPackageComponentItem *) [inPackageComponentTreeNode representedObject]).packageComponent;
	NSString * tName=tPackageComponent.packageSettings.name;
	
	if ([tName compare:inNewName]==NSOrderedSame)
		return NO;
	
	if ([tName caseInsensitiveCompare:inNewName]!=NSOrderedSame)
	{
		NSUInteger tLength=inNewName.length;
		NSIndexSet * tReloadRowIndexes=[NSIndexSet indexSetWithIndex:[inOutlineView rowForItem:inPackageComponentTreeNode]];
		NSIndexSet * tReloadColumnIndexes=[NSIndexSet indexSetWithIndex:[inOutlineView columnWithIdentifier:@"sourcelist.name"]];
		
		if (tLength==0)
		{
			[inOutlineView reloadDataForRowIndexes:tReloadRowIndexes columnIndexes:tReloadColumnIndexes];
			return NO;
		}
		
		void (^renameAlertBailOut)(NSString *,NSString *) = ^(NSString *bMessageText,NSString *bInformativeText)
		{
			NSAlert * tAlert=[NSAlert new];
			tAlert.alertStyle=NSCriticalAlertStyle;
			tAlert.messageText=bMessageText;
			tAlert.informativeText=bInformativeText;
			
			[tAlert runModal];
		};
		
		if (tLength>=256)
		{
			renameAlertBailOut([NSString stringWithFormat:NSLocalizedString(@"The name \"%@\" can't be used.",@""),inNewName],NSLocalizedString(@"Try using a name with fewer characters.",@""));
			
			return NO;
		}
		
		if ([inNewName isEqualToString:@".."]==YES ||
			[inNewName isEqualToString:@"."]==YES ||
			[inNewName rangeOfString:@"/"].location!=NSNotFound)
		{
			renameAlertBailOut([NSString stringWithFormat:NSLocalizedString(@"The name \"%@\" can't be used.",@""),inNewName],NSLocalizedString(@"Try using a name with no punctuation marks.",@""));
			
			return NO;
		}
		
		if ([self.packageComponents indexesOfObjectsPassingTest:^BOOL(PKGPackageComponent * bPackageComponent,NSUInteger bIndex,BOOL * bOutStop){
			
			return ([bPackageComponent.packageSettings.name caseInsensitiveCompare:inNewName]==NSOrderedSame);
			
		}].count>0)
		{
			renameAlertBailOut([NSString stringWithFormat:NSLocalizedString(@"The name \"%@\" is already taken.",@""),inNewName],NSLocalizedString(@"Please choose a different name.",@""));
			
			return NO;
		}
	}
	
	return YES;
}

- (BOOL)outlineView:(NSOutlineView *)inOutlineView renamePackageComponent:(PKGDistributionProjectSourceListTreeNode *)inPackageComponentTreeNode as:(NSString *)inNewName
{
	if (inOutlineView==nil || inPackageComponentTreeNode==nil || inNewName==nil)
		return NO;
	
	PKGPackageComponent * tPackageComponent=((PKGDistributionProjectSourceListPackageComponentItem *) [inPackageComponentTreeNode representedObject]).packageComponent;
	tPackageComponent.packageSettings.name=inNewName;
	
	[inPackageComponentTreeNode.parent sortChildrenUsingComparator:^NSComparisonResult(PKGDistributionProjectSourceListTreeNode * bTreeNode1,PKGDistributionProjectSourceListTreeNode * bTreeNode2){
	
		return [((PKGDistributionProjectSourceListPackageComponentItem *) [bTreeNode1 representedObject]).packageComponent.packageSettings.name caseInsensitiveCompare:((PKGDistributionProjectSourceListPackageComponentItem *) [bTreeNode2 representedObject]).packageComponent.packageSettings.name];
		
	}];
	
	[self.delegate sourceListDataDidChange:self];
	
	[inOutlineView reloadData];
	
	NSInteger tSelectedRow=[inOutlineView rowForItem:inPackageComponentTreeNode];
	
	if (tSelectedRow!=-1)
	{
		[inOutlineView scrollRowToVisible:tSelectedRow];
		[inOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:tSelectedRow] byExtendingSelection:NO];
	}
	
	return YES;
}

- (void)outlineView:(NSOutlineView *)inOutlineView duplicateItems:(NSArray *)inItems
{
	if (inOutlineView==nil || inItems.count==0)
		return;
	
	__block NSMutableArray * tTemporaryComponents=[self.packageComponents mutableCopy];
	
	NSArray * tDuplicatedPackageComponents=[inItems WB_arrayByMappingObjectsLenientlyUsingBlock:^PKGPackageComponent *(PKGDistributionProjectSourceListTreeNode * bSourceListTreeNode, NSUInteger bIndex) {

		PKGDistributionProjectSourceListPackageComponentItem * tPackageComponentItem=[bSourceListTreeNode representedObject];
		
		PKGPackageComponent * tNewPackageComponent=[tPackageComponentItem.packageComponent copy];
		
		// Unique Name
		
		__block NSString * tBaseName=tNewPackageComponent.packageSettings.name;
		
		NSString * tPattern=[NSString stringWithFormat:@"%@ ?[0-9]*$",NSLocalizedString(@" copy", @"")];
		
		NSRegularExpression * tRegularExpression=[NSRegularExpression regularExpressionWithPattern:tPattern options:NSRegularExpressionCaseInsensitive error:NULL];
		
		[tRegularExpression enumerateMatchesInString:tBaseName options:NSMatchingReportCompletion range:NSMakeRange(0,tBaseName.length) usingBlock:^(NSTextCheckingResult * bResult, NSMatchingFlags bFlags, BOOL * bOutStop) {
			
			if (bResult.resultType!=NSTextCheckingTypeRegularExpression)
				return;
			
			tBaseName=[tBaseName substringToIndex:bResult.range.location];
			
			*bOutStop=YES;
		}];
		
		NSString * tNewName=[tTemporaryComponents uniqueNameWithBaseName:[tBaseName stringByAppendingString:NSLocalizedString(@" copy", @"")]
													  usingNameExtractor:^NSString *(PKGPackageComponent * bPackageComponent, NSUInteger bIndex) {
			return bPackageComponent.packageSettings.name;
		}];
		
		if (tNewName!=nil)
			tNewPackageComponent.packageSettings.name=tNewName;
		
		// Unique Identifier
		
		tBaseName=tNewPackageComponent.packageSettings.identifier;
		
		tPattern=@"-[0-9]*$";
		
		tRegularExpression=[NSRegularExpression regularExpressionWithPattern:tPattern options:NSRegularExpressionCaseInsensitive error:NULL];
		
		[tRegularExpression enumerateMatchesInString:tBaseName options:NSMatchingReportCompletion range:NSMakeRange(0,tBaseName.length) usingBlock:^(NSTextCheckingResult * bResult, NSMatchingFlags bFlags, BOOL * bOutStop) {
			
			if (bResult.resultType!=NSTextCheckingTypeRegularExpression)
				return;
			
			tBaseName=[tBaseName substringToIndex:bResult.range.location];
			
			*bOutStop=YES;
		}];
		
		NSString * tNewIdentifier=[tTemporaryComponents uniqueNameWithBaseName:tBaseName format:@"%@-%lu" options:NSCaseInsensitiveSearch usingNameExtractor:^NSString *(PKGPackageComponent *bPackageComponent,NSUInteger bIndex){
			
			return bPackageComponent.packageSettings.identifier;
		}];
		
		if (tNewIdentifier!=nil)
			tNewPackageComponent.packageSettings.identifier=tNewIdentifier;
		

		[tTemporaryComponents addObject:tNewPackageComponent];
		
		return tNewPackageComponent;
	}];
	
	[self outlineView:inOutlineView addPackageComponents:tDuplicatedPackageComponents];
}

- (void)outlineView:(NSOutlineView *)inOutlineView removeItems:(NSArray *)inItems
{
	if (inOutlineView==nil || inItems.count==0)
		return;
	
	// Save the selection if needed
	
	NSArray * tSavedSelectedItems=nil;
	
	if (inItems.count==1)
	{
		if ([inOutlineView isRowSelected:[inOutlineView rowForItem:inItems[0]]]==NO)
			tSavedSelectedItems=[inOutlineView WB_selectedItems];
	}
	
	NSInteger tFirstIndex=[inOutlineView rowForItem:inItems[0]];
	
	// Remove the packages
	
	for(PKGTreeNode * tTreeNode in inItems)
	{
		PKGDistributionProjectSourceListPackageComponentItem * tPackageComponentItem=[tTreeNode representedObject];
		
		// A COMPLETER
		
		[_packageComponents removeObject:tPackageComponentItem.packageComponent];
		
		[tTreeNode removeFromParent];
	}
	
	// Remove some groups if they don't have any descendant nodes
	
	NSMutableSet * tRemovableSet=[NSMutableSet set];
	
	for(PKGDistributionProjectSourceListTreeNode * tTreeNode in _forest.rootNodes)
	{
		PKGDistributionProjectSourceListGroupItem * tGroupItem=[tTreeNode representedObject];
		
		if ([tGroupItem isKindOfClass:PKGDistributionProjectSourceListGroupItem.class]==YES)
		{
			if (tTreeNode.numberOfChildren==0 && tGroupItem.groupType!=PKGPackageComponentTypeProject)
				[tRemovableSet addObject:tTreeNode];
		}
	}
	
	for(PKGDistributionProjectSourceListTreeNode * tTreeNode in tRemovableSet)
		[_forest.rootNodes removeObject:tTreeNode];
	
	[self.delegate sourceListDataDidChange:self];
	
	inOutlineView.allowsEmptySelection=YES;
	
	[inOutlineView deselectAll:nil];
	
	[inOutlineView reloadData];
	
	if (tSavedSelectedItems!=nil)
	{
		NSMutableIndexSet * tMutableIndexSet=[NSMutableIndexSet indexSet];
		
		for(id tItem in tSavedSelectedItems)
		{
			NSInteger tIndex=[inOutlineView rowForItem:tItem];
			
			if (tIndex!=-1)
				[tMutableIndexSet addIndex:tIndex];
		}
		
		[inOutlineView selectRowIndexes:tMutableIndexSet byExtendingSelection:NO];
	}
	
	if (inOutlineView.numberOfSelectedRows==0)
	{
		NSInteger tNewSelectionIndex=tFirstIndex-1;
		
		for(;tNewSelectionIndex>=1;tNewSelectionIndex--)
		{
			PKGDistributionProjectSourceListTreeNode * tTreeNode=[inOutlineView itemAtRow:tNewSelectionIndex];
			
			if (tTreeNode==nil)
				continue;
			
			PKGDistributionProjectSourceListPackageComponentItem * tPackageComponentItem=[tTreeNode representedObject];
			
			if ([tPackageComponentItem isKindOfClass:PKGDistributionProjectSourceListPackageComponentItem.class]==NO)
				continue;
			
			break;
		}
		
		[inOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:tNewSelectionIndex] byExtendingSelection:NO];
	}
	
	inOutlineView.allowsEmptySelection=NO;
}

@end
