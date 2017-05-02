
#import "PKGChoicesForest.h"

typedef NS_ENUM(NSInteger, PKGChoiceSelectedState) {
	PKGChoiceSelectedStateUnknown=-5,
	PKGChoiceSelectedStateMixed=-1,
	PKGChoiceSelectedStateOff=0,
	PKGChoiceSelectedStateOn=1,
	PKGChoiceSelectedStateDependent=2
};

@interface PKGChoiceTreeNode (UI)

	@property (nonatomic,readonly,copy) NSString * choiceUUID;

	@property (nonatomic,readonly,copy) NSString * packageUUID;

	@property (nonatomic,readonly,getter=isInvisible) BOOL invisible;

	@property (nonatomic,readonly,getter=isEnabled) BOOL enabled;

	@property (nonatomic,readonly,getter=isPackageChoice) BOOL packageChoice;

	@property (nonatomic,readonly,getter=isMergedPackageChoice) BOOL mergedPackageChoice;

	@property (nonatomic,readonly) PKGChoiceSelectedState selectedState;

	//@property (nonatomic,readonly,copy) NSString * nameTitle;

	@property (nonatomic,readonly,copy) NSString * choiceAction;

- (NSString *)titleForLocalization:(NSString *)inLocalization;

@end
