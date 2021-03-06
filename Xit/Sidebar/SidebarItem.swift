import Cocoa

class SidebarItem: NSObject
{
  var title: String
  var displayTitle: UIString { return UIString(rawValue: title) }
  var icon: NSImage? { return nil }
  var children: [SidebarItem]
  var selection: RepositorySelection?
  var refType: RefType { return .unknown }
  var expandable: Bool { return false }
  // NSObject.isSelectable is new in 10.12
  override var isSelectable: Bool { return true }
  var editable: Bool { return false }
  var current: Bool { return false }
  
  init(title: String)
  {
    self.title = title
    self.children = []
    
    super.init()
  }
  
  convenience init(title: String, selection: RepositorySelection)
  {
    self.init(title: title)
    self.selection = selection
  }
  
  func child(matching title: String) -> SidebarItem?
  {
    if let child = children.first(where: { $0.title == title }) {
      return child
    }
    if let child = children.firstResult({ $0.child(matching: title) }) {
      return child
    }
    return nil
  }
  
  /// Returns the first match in the hierarchy of child items
  func findChild(_ predicate: (SidebarItem) -> Bool) -> SidebarItem?
  {
    if predicate(self) {
      return self
    }
    else {
      return children.firstResult { $0.findChild(predicate) }
    }
  }
  
  override var description: String { return self.title }
}


class SideBarGroupItem: SidebarItem
{
  init(titleString: UIString)
  {
    super.init(title: titleString.rawValue)
  }
  
  override var isSelectable: Bool { return false }
  override var expandable: Bool { return true }
}


class StagingSidebarItem: SidebarItem
{
  init(titleString: UIString)
  {
    super.init(title: titleString.rawValue)
  }
  
  override var icon: NSImage?
  {
    return NSImage(named: .xtStagingTemplate)
  }
}


class StashSidebarItem: SidebarItem
{
  override var icon: NSImage?
  {
    return NSImage(named: .xtStashTemplate)
  }
}


class BranchSidebarItem: SidebarItem
{
  override var displayTitle: UIString
  { return UIString(rawValue: (title as NSString).lastPathComponent) }
  override var icon: NSImage?
  { return NSImage(named: .xtBranchTemplate) }
  
  var fullName: String { return title }
  var refName: String { fatalError("refName is abstract") }
  var remote: Remote? { return nil }
  
  func branchObject() -> Branch? { return nil }
}


class LocalBranchSidebarItem: BranchSidebarItem
{
  override var refType: RefType { return current ? .activeBranch : .branch }
  override var current: Bool
  {
    if let currentBranch = selection!.repository.currentBranch {
      return currentBranch == title
    }
    return false
  }
  
  override var refName: String
  { return RefPrefixes.heads.appending(pathComponent: title) }
  
  override func branchObject() -> Branch?
  {
    return selection!.repository.localBranch(named: title)
  }
  
  override var remote: Remote?
  {
    guard let localBranch = branchObject() as? LocalBranch,
          let remoteBranch = localBranch.trackingBranch,
          let repo = selection!.repository as? RemoteManagement
    else { return nil }
    
    return remoteBranch.remoteName.flatMap { repo.remote(named: $0) }
  }

  func hasTrackingBranch() -> Bool
  {
    let branch = selection!.repository.localBranch(named: title)
    
    return branch?.trackingBranchName != nil
  }
}


class RemoteBranchSidebarItem: BranchSidebarItem
{
  var remoteName: String
  override var remote: Remote?
  {
    return (selection!.repository as? RemoteManagement)?.remote(named: remoteName)
  }
  override var refType: RefType { return .remoteBranch }
  
  override var fullName: String { return "\(remoteName)/\(title)" }
  
  override var refName: String
  { return RefPrefixes.remotes.appending(pathComponent: fullName) }

  init(title: String, remote: String, selection: RepositorySelection)
  {
    self.remoteName = remote
    
    super.init(title: title)
    self.selection = selection
  }
  
  override func branchObject() -> Branch?
  {
    return selection!.repository.remoteBranch(named: title, remote: remoteName)
  }
}


class BranchFolderSidebarItem: SidebarItem
{
  override var icon: NSImage? { return NSImage(named: .xtFolderTemplate) }
  override var isSelectable: Bool { return false }
  override var expandable: Bool { return true }
}


class RemoteSidebarItem: SidebarItem
{
  let remote: Remote?
  
  override var icon: NSImage?
  {
    if let urlString = remote?.urlString,
       let url = URL(string: urlString),
       let host = url.host {
      if (host == "github.com") || host.hasSuffix(".github.com") {
        return NSImage(named: .xtGitHubTemplate)
      }
    }
    return NSImage(named: .xtCloudTemplate)
  }
  
  override var expandable: Bool { return true }
  override var editable: Bool { return true }
  override var refType: RefType { return .remote }
  
  init(title: String, repository: XTRepository)
  {
    self.remote = repository.remote(named: title)
    
    super.init(title: title)
  }
}


class TagSidebarItem: SidebarItem
{
  let tag: Tag

  override var displayTitle: UIString
  { return UIString(rawValue: (title as NSString).lastPathComponent) }
  override var icon: NSImage?
  { return NSImage(named: .xtTagTemplate) }
  override var refType: RefType { return .tag }
  
  init(tag: Tag)
  {
    self.tag = tag
    
    super.init(title: tag.name)
    
    // The cast to GitTag is unfortunate but hard to get around. It doesn't seem
    // to make sense to have a repository property in the Tag protocol.
    if let commit = tag.commit,
       let xtTag = tag as? GitTag {
      self.selection = CommitSelection(repository: xtTag.repository,
                                       commit: commit)
    }
  }
}


class SubmoduleSidebarItem: SidebarItem
{
  let submodule: Submodule
  override var icon: NSImage?
  { return NSImage(named: .xtSubmoduleTemplate) }
  
  init(submodule: Submodule)
  {
    self.submodule = submodule
    
    super.init(title: submodule.name)
  }
}
