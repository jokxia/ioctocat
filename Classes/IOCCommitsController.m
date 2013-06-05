#import "IOCCommitsController.h"
#import "IOCCommitController.h"
#import "IOCCommitCell.h"
#import "GHCommits.h"
#import "GHCommit.h"
#import "iOctocat.h"
#import "NSString+Extensions.h"
#import "IOCResourceStatusCell.h"
#import "SVProgressHUD.h"
#import "UIScrollView+SVInfiniteScrolling.h"


@interface IOCCommitsController ()
@property(nonatomic,strong)GHCommits *commits;
@property(nonatomic,strong)IOCResourceStatusCell *statusCell;
@end


@implementation IOCCommitsController

- (id)initWithCommits:(GHCommits *)commits {
	self = [super initWithStyle:UITableViewStylePlain];
	if (self) {
		self.commits = commits;
	}
	return self;
}

#pragma mark View Events

- (void)viewDidLoad {
	[super viewDidLoad];
	self.navigationItem.title = self.title ? self.title : @"Commits";
	if (!self.commits.resourcePath.isEmpty) {
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refresh:)];
	}
	self.statusCell = [[IOCResourceStatusCell alloc] initWithResource:self.commits name:@"commits"];
    [self setupInfiniteScrolling];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	if (self.commits.isUnloaded) {
		[self.commits loadWithSuccess:^(GHResource *instance, id data) {
            [self displayCommits];
		}];
	} else if (self.commits.isChanged) {
		[self displayCommits];
	}
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[SVProgressHUD dismiss];
}

#pragma mark Helpers

- (void)displayCommits {
    [self.tableView reloadData];
    self.tableView.showsInfiniteScrolling = self.commits.hasNextPage;
}

- (void)setupInfiniteScrolling {
	__weak __typeof(&*self)weakSelf = self;
	[self.tableView addInfiniteScrollingWithActionHandler:^{
        [weakSelf.commits loadNextWithStart:NULL success:^(GHResource *instance, id data) {
            [weakSelf displayCommits];
            [weakSelf.tableView.infiniteScrollingView stopAnimating];
        } failure:^(GHResource *instance, NSError *error) {
            [weakSelf.tableView.infiniteScrollingView stopAnimating];
            [iOctocat reportLoadingError:@"Could not load more entries"];
        }];
	}];
}

#pragma mark Actions

- (IBAction)refresh:(id)sender {
	if (self.commits.isLoading) return;
	[self.commits loadWithParams:nil start:^(GHResource *instance) {
		instance.isEmpty ? [self displayCommits] : [SVProgressHUD showWithStatus:@"Reloading"];
	} success:^(GHResource *instance, id data) {
		[SVProgressHUD dismiss];
		[self displayCommits];
	} failure:^(GHResource *instance, NSError *error) {
		instance.isEmpty ? [self displayCommits] : [SVProgressHUD showErrorWithStatus:@"Reloading failed"];
	}];
}

#pragma mark TableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return self.commits.isEmpty ? 1 : self.commits.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (self.commits.isEmpty) return self.statusCell;
	IOCCommitCell *cell = [tableView dequeueReusableCellWithIdentifier:kCommitCellIdentifier];
	if (cell == nil) cell = [IOCCommitCell cell];
	cell.commit = self.commits[indexPath.row];
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (self.commits.isEmpty) return;
	GHCommit *commit = self.commits[indexPath.row];
	IOCCommitController *viewController = [[IOCCommitController alloc] initWithCommit:commit];
	[self.navigationController pushViewController:viewController animated:YES];
}

- (BOOL)tableView:(UITableView *)tableView shouldShowMenuForRowAtIndexPath:(NSIndexPath *)indexPath {
    return !self.commits.isEmpty;
}

- (BOOL)tableView:(UITableView *)tableView canPerformAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
    if (action == @selector(copy:)) {
        return YES;
    }
    return NO;
}

- (void)tableView:(UITableView *)tableView performAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
    GHCommit *commit = self.commits[indexPath.row];
    [UIPasteboard generalPasteboard].string = commit.shortenedSha;
}

#pragma mark Responder

- (BOOL)canBecomeFirstResponder {
    return YES;
}

@end