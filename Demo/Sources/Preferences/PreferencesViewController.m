//
//  Copyright (c) SRG SSR. All rights reserved.
//
//  License information is available from the LICENSE file.
//

#import "PreferencesViewController.h"

#import "SRGUserData_demo-Swift.h"

#import <SRGIdentity/SRGIdentity.h>
#import <SRGUserData/SRGUserData.h>

static NSNumberFormatter *PreferencesNumberFormatter(void)
{
    static dispatch_once_t s_onceToken;
    static NSNumberFormatter *s_numberFormatter;
    dispatch_once(&s_onceToken, ^{
        s_numberFormatter = [[NSNumberFormatter alloc] init];
        s_numberFormatter.numberStyle = NSNumberFormatterDecimalStyle;
    });
    return s_numberFormatter;
}

@interface PreferencesViewController ()

@property (nonatomic, copy) NSString *path;
@property (nonatomic, copy) NSString *domain;

@property (nonatomic) NSArray *keys;
@property (nonatomic) NSDictionary *dictionary;

@end

@implementation PreferencesViewController

#pragma mark Object lifecycle

- (instancetype)initWithPath:(NSString *)path inDomain:(NSString *)domain
{
    if (self = [super init]) {
        self.path = path;
        self.domain = domain;
    }
    return self;
}

#pragma mark Getters and setters

- (NSString *)title
{
    return self.path.lastPathComponent ?: NSLocalizedString(@"Preferences", nil);
}

#pragma mark View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(preferencesDidChange:)
                                               name:SRGPreferencesDidChangeNotification
                                             object:SRGUserData.currentUserData.preferences];
    
#if TARGET_OS_IOS
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                                           target:self
                                                                                           action:@selector(addPreference:)];
#endif
}

#pragma mark Data

- (void)refresh
{
    self.dictionary = [SRGUserData.currentUserData.preferences dictionaryAtPath:self.path inDomain:self.domain];
    
    NSArray<NSString *> *keys = [self.dictionary.allKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    [self.tableView reloadDataAnimatedWithOldObjects:self.keys newObjects:keys section:0 updateData:^{
        self.keys = keys;
    }];
}

#pragma mark UITableViewDataSourceProtocol

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
#if TARGET_OS_IOS
    return self.keys.count;
#else
    return self.keys.count + 1;
#endif
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString * const kCellIdentifier = @"PreferenceCell";
    
    // Use old-fashioned instantiation to customize the cell style
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellIdentifier];
    if (! cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:kCellIdentifier];
    }
    return cell;
}

#pragma mark UITableViewDelegate protocol

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row < self.keys.count) {
        NSString *key = self.keys[indexPath.row];
        cell.textLabel.text = key;

        id value = self.dictionary[key];
        if ([value isKindOfClass:NSString.class]) {
            cell.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedString(@"String: %@", nil), value];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        }
        else if ([value isKindOfClass:NSNumber.class]) {
            if (value == (void *)kCFBooleanTrue || value == (void *)kCFBooleanFalse) {
                cell.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Boolean: %@", nil), [value boolValue] ? @"true" : @"false"];
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            }
            else {
                cell.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Number: %@", nil), [PreferencesNumberFormatter() stringFromNumber:value]];
                cell.accessoryType = UITableViewCellAccessoryNone;
                cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            }
        }
        else if ([value isKindOfClass:NSDictionary.class]) {
            cell.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Dictionary", nil)];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
        else if ([value isKindOfClass:NSArray.class]) {
            cell.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Array (%@ objects)", nil), [value count]];
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
        else {
            cell.detailTextLabel.text = nil;
            cell.accessoryType = UITableViewCellAccessoryNone;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
    }
    else {
        cell.textLabel.text = NSLocalizedString(@"Add preference", nil);
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.row < self.keys.count) {
        NSString *key = self.keys[indexPath.row];
        NSString *subpath = [self.path stringByAppendingPathComponent:key] ?: key;
        
        id value = self.dictionary[key];
        if ([value isKindOfClass:NSString.class]) {
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Edit string", nil)
                                                                                     message:nil
                                                                              preferredStyle:UIAlertControllerStyleAlert];
            [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
                textField.placeholder = NSLocalizedString(@"Value", nil);
            }];
            [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
            [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Save", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                NSString *string = [alertController.textFields.lastObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
                [SRGUserData.currentUserData.preferences setString:string atPath:subpath inDomain:self.domain];
            }]];
            [self presentViewController:alertController animated:YES completion:nil];
        }
        else if ([value isKindOfClass:NSNumber.class]) {
            if (value == (void *)kCFBooleanTrue || value == (void *)kCFBooleanFalse) {
                UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Edit boolean", nil)
                                                                                         message:nil
                                                                                  preferredStyle:UIAlertControllerStyleAlert];
                [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
                [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"True", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    [SRGUserData.currentUserData.preferences setNumber:@YES atPath:subpath inDomain:self.domain];
                }]];
                [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"False", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    [SRGUserData.currentUserData.preferences setNumber:@NO atPath:subpath inDomain:self.domain];
                }]];
                [self presentViewController:alertController animated:YES completion:nil];
            }
            else {
                UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Edit number", nil)
                                                                                         message:nil
                                                                                  preferredStyle:UIAlertControllerStyleAlert];
                [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
                    textField.placeholder = NSLocalizedString(@"Value", nil);
                }];
                [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
                [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Save", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    NSString *numberString = [alertController.textFields.lastObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
                    NSNumber *number = [PreferencesNumberFormatter() numberFromString:numberString];
                    [SRGUserData.currentUserData.preferences setNumber:number atPath:subpath inDomain:self.domain];
                }]];
                [self presentViewController:alertController animated:YES completion:nil];
            }
        }
        else if ([value isKindOfClass:NSDictionary.class]) {
            PreferencesViewController *preferencesViewController = [[PreferencesViewController alloc] initWithPath:subpath inDomain:self.domain];
            [self.navigationController pushViewController:preferencesViewController animated:YES];
        }
    }
    else {
        [self addPreference:nil];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return (indexPath.row < self.keys.count);
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSString *key = self.keys[indexPath.row];
        NSString *subpath = [self.path stringByAppendingPathComponent:key] ?: key;
        [SRGUserData.currentUserData.preferences removeObjectsAtPaths:@[subpath] inDomain:self.domain];
    }
}

#pragma mark Actions

- (void)addPreference:(id)sender
{
    UIAlertController *alertController1 = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Add setting", nil)
                                                                              message:nil
                                                                       preferredStyle:UIAlertControllerStyleActionSheet];
    [alertController1 addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"String", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UIAlertController *alertController2 = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Add string", nil)
                                                                                  message:nil
                                                                           preferredStyle:UIAlertControllerStyleAlert];
        [alertController2 addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            textField.placeholder = NSLocalizedString(@"Path", nil);
        }];
        [alertController2 addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            textField.placeholder = NSLocalizedString(@"Value", nil);
        }];
        [alertController2 addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
        [alertController2 addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Add", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSString *path = [alertController2.textFields[0].text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (path.length != 0) {
                NSString *subpath = [self.path stringByAppendingPathComponent:path] ?: path;
                NSString *string = [alertController2.textFields.lastObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
                [SRGUserData.currentUserData.preferences setString:string atPath:subpath inDomain:self.domain];
            }
        }]];
        [self presentViewController:alertController2 animated:YES completion:nil];
    }]];
    [alertController1 addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Number", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UIAlertController *alertController2 = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Add number", nil)
                                                                                  message:nil
                                                                           preferredStyle:UIAlertControllerStyleAlert];
        [alertController2 addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            textField.placeholder = NSLocalizedString(@"Path", nil);
        }];
        [alertController2 addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            textField.placeholder = NSLocalizedString(@"Value", nil);
            textField.keyboardType = UIKeyboardTypeNumberPad;
        }];
        [alertController2 addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
        [alertController2 addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Add", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSString *path = [alertController2.textFields[0].text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (path.length != 0) {
                NSString *value = [alertController2.textFields[1].text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
                NSNumber *number = [PreferencesNumberFormatter() numberFromString:value];
                
                NSString *subpath = [self.path stringByAppendingPathComponent:path] ?: path;
                [SRGUserData.currentUserData.preferences setNumber:number atPath:subpath inDomain:self.domain];
            }
        }]];
        [self presentViewController:alertController2 animated:YES completion:nil];
    }]];
    [alertController1 addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Boolean", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UIAlertController *alertController2 = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Add boolean", nil)
                                                                                  message:nil
                                                                           preferredStyle:UIAlertControllerStyleAlert];
        [alertController2 addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            textField.placeholder = NSLocalizedString(@"Path", nil);
        }];
        [alertController2 addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
        [alertController2 addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"True", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSString *path = [alertController2.textFields[0].text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (path.length != 0) {
                NSString *subpath = [self.path stringByAppendingPathComponent:path] ?: path;
                [SRGUserData.currentUserData.preferences setNumber:@YES atPath:subpath inDomain:self.domain];
            }
        }]];
        [alertController2 addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"False", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSString *path = [alertController2.textFields[0].text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (path.length != 0) {
                NSString *subpath = [self.path stringByAppendingPathComponent:path] ?: path;
                [SRGUserData.currentUserData.preferences setNumber:@NO atPath:subpath inDomain:self.domain];
            }
        }]];
        [self presentViewController:alertController2 animated:YES completion:nil];
    }]];
    [alertController1 addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:nil]];
    
#if TARGET_OS_IOS
    UIPopoverPresentationController *popoverPresentationController = alertController1.popoverPresentationController;
    popoverPresentationController.barButtonItem = sender;
#endif
    
    [self presentViewController:alertController1 animated:YES completion:nil];
}

#pragma mark Notifications

- (void)preferencesDidChange:(NSNotification *)notification
{
    [self refresh];
}

@end
