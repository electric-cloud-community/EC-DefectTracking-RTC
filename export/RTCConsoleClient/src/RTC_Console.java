package rtc_console;

//            -------- Version History --------
//
// Note: Please update this log, and the version string (several
// pages below) with each change to this code!
//
// 2.0.0 - MJW - Initial working version
//
// 2.0.1 - MJW - Look up workitem type, as we do with other types
//
// 2.1.0 - MJW - Packaged and qualified with RTC 4.0.2 Java Lib
//               Note that this means we no longer support RTC 3.x with this
//               and newer versions of this plugin.

import java.net.URI;
import java.net.URISyntaxException;
import java.util.List;
import org.eclipse.core.runtime.AssertionFailedException;
import org.eclipse.core.runtime.IProgressMonitor;
import com.ibm.team.foundation.common.text.XMLString;
import com.ibm.team.links.common.IItemReference;
import com.ibm.team.links.common.IReference;
import com.ibm.team.links.common.IURIReference;
import com.ibm.team.links.common.factory.IReferenceFactory;
import com.ibm.team.links.common.registry.IEndPointDescriptor;
import com.ibm.team.links.common.registry.ILinkTypeRegistry;
import com.ibm.team.process.client.IProcessClientService;
import com.ibm.team.process.client.IProcessItemService;
import com.ibm.team.process.common.IProjectArea;
import com.ibm.team.repository.client.IItemManager;
import com.ibm.team.repository.client.ITeamRepository;
import com.ibm.team.repository.client.ITeamRepository.ILoginHandler;
import com.ibm.team.repository.client.ITeamRepository.ILoginHandler.ILoginInfo;
import com.ibm.team.repository.client.TeamPlatform;
import com.ibm.team.repository.common.ItemNotFoundException;
import com.ibm.team.repository.common.IAuditable;
import com.ibm.team.repository.common.IContent;
import com.ibm.team.repository.common.IItemType;
import com.ibm.team.repository.common.Location;
import com.ibm.team.repository.common.TeamRepositoryException;
import com.ibm.team.workitem.client.IAuditableClient;
import com.ibm.team.workitem.client.IDetailedStatus;
import com.ibm.team.workitem.client.IWorkItemClient;
import com.ibm.team.workitem.client.IWorkItemWorkingCopyManager;
import com.ibm.team.workitem.client.WorkItemOperation;
import com.ibm.team.workitem.client.WorkItemWorkingCopy;
import com.ibm.team.workitem.common.model.IAttachment;
import com.ibm.team.workitem.common.model.ICategory;
import com.ibm.team.workitem.common.model.IResolution;
import com.ibm.team.workitem.common.model.IState;
import com.ibm.team.workitem.common.model.ItemProfile;
import com.ibm.team.workitem.common.model.IWorkItem;
import com.ibm.team.workitem.common.model.IWorkItemHandle;
import com.ibm.team.workitem.common.model.IWorkItemType;
import com.ibm.team.workitem.common.model.IWorkItemReferences;
import com.ibm.team.workitem.common.model.Identifier;
import com.ibm.team.workitem.common.model.WorkItemEndPoints;
import com.ibm.team.workitem.common.model.WorkItemLinkTypes;
import com.ibm.team.workitem.common.workflow.IWorkflowInfo;
import com.ibm.team.workitem.common.workflow.IWorkflowAction;

public class RTC_Console {

    private static class LoginHandler implements ILoginHandler, ILoginInfo {

        private final String userId;
        private final String password;

        private LoginHandler(final String userId, final String password) {
            this.userId = userId;
            this.password = password;
        }

        public String getUserId() {
            return userId;
        }

        public String getPassword() {
            return password;
        }

        public ILoginInfo challenge(final ITeamRepository repository) {
            return this;
        }
    }

    public static void main(String[] args) {

	String UtilityVersion = "2.1.0";

	// Need at least 4 arguments: UserId, Password, URI, and operation
        if (args.length < 4) Usage("Error: insufficient command-line arguments.");

        // Fetch the command line arguments
        String rtcUserId = args[0];
        String rtcPasswd = args[1];
        String rtcRepURI = args[2];
        String operation = args[3];

	// Validate operation
	if ( !operation.equalsIgnoreCase("QueryItem" ) &&
	     !operation.equalsIgnoreCase("UpdateItem") &&
	     !operation.equalsIgnoreCase("AddItem"   ) &&
	     !operation.equalsIgnoreCase("DumpInfo"  )) {
	    Usage("Invalid operation: " + operation);
	}

	// Fetch remainder of arguments from environment
	String rtcWorkitem     = System.getenv("RTCWORKITEM");
	String rtcWorkitemType = System.getenv("RTCWORKITEMTYPE");
	String rtcAction       = System.getenv("RTCACTION");
        String rtcResolution   = System.getenv("RTCRESOLUTION");
	String rtcLinkRAURI    = System.getenv("RTCLINK_RA_URI");
	String rtcLinkRAText   = System.getenv("RTCLINK_RA_TEXT");
        String rtcProjectArea  = System.getenv("RTCPROJECTAREA");
        String rtcSummary      = System.getenv("RTCSUMMARY");
        String rtcDescription  = System.getenv("RTCDESCRIPTION");

	// Hack to permit command-line specification for workitem
	if ((rtcWorkitem == null) && (args.length > 4)) rtcWorkitem = args[4]; 

	// Handle any conversions required by provided inputs, before we get
	// too far into the RTC session:

	// - Convert the workitem to an integer value and validate
        int workitemId = -1;
	if (rtcWorkitem != null) {
	    try {
		workitemId = Integer.parseInt(rtcWorkitem);
	    } catch (NumberFormatException e) {
		Usage("Error: non-numeric workitem value specified: " + rtcWorkitem);
	    }
	}
	if ((workitemId < 0) && (! operation.equalsIgnoreCase("AddItem"))) {
	    Usage("Error: A workitem ID must be provided.");
	}

	// - Default workitem type (for creation) is "defect" - make it so.
	if (rtcWorkitemType == null) {
	    rtcWorkitemType = "defect";
	}

	// - MJW - TODO: validate other strings here (eg: summary req'd if AddItem, etc.)


	// Start the heavy lifting
        TeamPlatform.startup();
        try {
            IProgressMonitor m = null;
            ITeamRepository repo = login(rtcRepURI, rtcUserId, rtcPasswd, m);

            // Query Item for linking on given ID.
            if (operation.equalsIgnoreCase("QueryItem")) {
                QueryItem(repo, m, workitemId);

            }

            // Dump Info on item - diagnostic/debug/development only.
            else if (operation.equalsIgnoreCase("DumpInfo")) {
                DumpInfo(repo, m, UtilityVersion, workitemId);

            }

            // Add Item case and ID resolve for linking property.
            else if (operation.equalsIgnoreCase("AddItem")) {
                // Replace spaces in the project name with %20
                URI uri = URI.create(rtcProjectArea.replaceAll(" ", "%20"));
                // Find Project
                IProcessItemService processItemService =
		    (IProcessItemService) repo.getClientLibrary(IProcessItemService.class);
                IProjectArea projectArea =
		    (IProjectArea) processItemService.findProcessArea(uri, null, m);
		// Fail if no project area, otherwise add the item
                if (projectArea == null) {
                    System.err.println("Error: Project area not found: " + rtcProjectArea);
                } else {
		    AddItem(repo, m, projectArea, rtcWorkitemType, rtcSummary,
			    rtcDescription, rtcLinkRAURI, rtcLinkRAText);
		}
            }

            // Update Item on a given ID and return properties for linking.
            else if (operation.equalsIgnoreCase("UpdateItem")) {
                // Update WorkItem
                UpdateItem(repo, m, workitemId, rtcAction, rtcResolution,
			   rtcLinkRAURI, rtcLinkRAText, rtcDescription);
            }
	    // Oops.
	    else {
		System.err.println("Error: Unrecognized operation: " + operation);
	    }

            // Log out of the repository
            repo.logout();

        } catch (NumberFormatException e) {
            System.err.println("Error: trying to convert to integer: " + e.getMessage());
        } catch (AssertionFailedException e) {
            System.err.println(e.getMessage());
        } catch (IllegalStateException e) {
            System.err.println(e.getMessage());
        } catch (ItemNotFoundException e) {
            System.err.println(e.getMessage());
        } catch (TeamRepositoryException e) {
            System.err.println("Error: TeamRepository: " + e.getMessage());
        } finally {
            TeamPlatform.shutdown();
        }
    }

    // Login to repository
    private static ITeamRepository login(String r, String user, String pw, IProgressMonitor m)
            throws TeamRepositoryException {
        ITeamRepository trepo = TeamPlatform.getTeamRepositoryService().getTeamRepository(r);
        trepo.registerLoginHandler(new LoginHandler(user, pw));
        trepo.login(m);
        return trepo;
    }

    // Add a new Defect
    public static IWorkItemHandle AddItem(ITeamRepository repository, IProgressMonitor m,
					  IProjectArea pa, String workitemTypeName, String summary,
					  String description, String linkURI, String linkText)
	throws TeamRepositoryException {

        IWorkItemClient wc_service = (IWorkItemClient) repository.getClientLibrary(IWorkItemClient.class);
	// 
        //IWorkItemType workItemType = wc_service.findWorkItemType(pa, workitemTypeName, m);
        IWorkItemType workItemType = null;
	List<IWorkItemType> types = wc_service.findWorkItemTypes(pa, m);
	for (IWorkItemType witype : types) {
	    if (witype.getDisplayName().equalsIgnoreCase(workitemTypeName)) {
		workItemType = witype;
	    }
	}
        IWorkItemHandle handle = wc_service.getWorkItemWorkingCopyManager().connectNew(workItemType, m);
        WorkItemWorkingCopy wc = wc_service.getWorkItemWorkingCopyManager().getWorkingCopy(handle);
        IWorkItem item = wc.getWorkItem();
	IWorkItemReferences refs = wc.getReferences();

        try {
	    // MJW - TODO: Highly suspect - what have we hard-coded here? Needs to be researched.
            List<ICategory> findCategories = wc_service.findCategories(pa, ICategory.FULL_PROFILE, m);
            ICategory category = findCategories.get(0);
            item.setCategory(category);                                          // Category
            item.setCreator(repository.loggedInContributor());                   // Creator
            item.setOwner(repository.loggedInContributor());                     // Owner
            item.setHTMLSummary(XMLString.createFromPlainText(summary));         // Summary
            item.setHTMLDescription(XMLString.createFromPlainText(description)); // Description
	    IURIReference reference = makeRef(linkURI, linkText);                // Link
	    if (reference != null) {
		IEndPointDescriptor endpoint = ILinkTypeRegistry.INSTANCE.
		    getLinkType(WorkItemLinkTypes.RELATED_ARTIFACT).getTargetEndPointDescriptor();
		refs.add(endpoint, reference);
	    }

            IDetailedStatus status = wc.save(null);
            if (!status.isOK()) {
                throw new TeamRepositoryException("Error saving work item, "
						  + status.getMessage(), status.getException());
            }
        } finally {
            wc_service.getWorkItemWorkingCopyManager().disconnect(item);
        }
	// Read back the item we just saved, so we can report on it
        item = (IWorkItem) repository.itemManager().fetchCompleteItem(item, IItemManager.DEFAULT, m);
        IWorkflowInfo workflowInfo = wc_service.findWorkflowInfo(item, m);
        Print(item, workflowInfo, repository, m);
        return item;
    }

    // Update Defect status
    public static IWorkItemHandle UpdateItem(ITeamRepository repository,
					     IProgressMonitor m,
					     int WorkItemId,
					     String action,
					     String resolution,
					     String linkURI,
					     String linkText,
					     String description)
            throws TeamRepositoryException {

        IWorkItemClient wc_service = (IWorkItemClient) repository.getClientLibrary(IWorkItemClient.class);
        IWorkItem workItem = wc_service.findWorkItemById(WorkItemId,IWorkItem.FULL_PROFILE, m);
        if (workItem != null) {
            IWorkflowInfo workflowInfo = wc_service.findWorkflowInfo(workItem, m);
            IWorkItemWorkingCopyManager workingCopyManager = wc_service.getWorkItemWorkingCopyManager();
            IWorkItemHandle handle = wc_service.findWorkItemById(WorkItemId, IWorkItem.FULL_PROFILE, m);
            workingCopyManager.connect(handle, IWorkItem.FULL_PROFILE, m);
            WorkItemWorkingCopy wc = workingCopyManager.getWorkingCopy(handle);
            IWorkItem item = wc.getWorkItem();
	    IWorkItemReferences refs = wc.getReferences();

            String currentState = item.getState2().getStringIdentifier();
            String currentStateName = workflowInfo.getStateName(item.getState2());
            System.out.println("//DEBUG: currentState: " + currentState + " (" + currentStateName + ")");

	    String actionId = null;
	    // if an action was provided, look up the action name and translate it to
	    // the action identifier string that we need to use.
	    if (action != null) {
		System.out.println("//DEBUG: requested action: " + action);
		Identifier<IWorkflowAction> actionIds[] = workflowInfo.getAllActionIds();
		for (Identifier<IWorkflowAction> a : actionIds) {
		    if (workflowInfo.getActionName(a).equalsIgnoreCase(action)) {
			actionId = a.getStringIdentifier();
		    }
		}
		if (actionId == null) {
		    System.err.println("Error: ignoring invalid requested action: " + action);
		}
	    }

	    String currentResolutionName = "";
	    if (item.getResolution2() != null) {
		currentResolutionName = workflowInfo.getResolutionName(item.getResolution2());
		System.out.println("//DEBUG: current resolution: " + currentResolutionName);
	    }

            Identifier<IResolution> iResolution = null;
	    // if a resolution was provided, look up the resolution name and translate it to
	    // the resolution identifier string that we need to use.
	    if (resolution != null) {
		System.out.println("//DEBUG: requested resolution: " + resolution);
		Identifier<IResolution> resIds[] = workflowInfo.getAllResolutionIds();
		for (Identifier<IResolution> r : resIds) {
		    if (workflowInfo.getResolutionName(r).equalsIgnoreCase(resolution)) {
			iResolution = r;
		    }
		}
		if (iResolution == null) {
		    System.err.println("Error: ignoring invalid resolution: " + resolution);
		}
	    }

	    IEndPointDescriptor endpoint =
		ILinkTypeRegistry.INSTANCE.getLinkType(WorkItemLinkTypes.RELATED_ARTIFACT)
		    .getTargetEndPointDescriptor();
	    IURIReference reference = makeRef(linkURI, linkText);

            try {
		if (reference != null) {
		    refs.add(endpoint, reference);
		}
		if (iResolution != null) {
		    item.setResolution2(iResolution);
		}
		if (action != null) {
		    wc.setWorkflowAction(actionId);
		}
                IDetailedStatus status = wc.save(m);
                if (!status.isOK()) {
                    throw new TeamRepositoryException( "Error updating item: " + status.getMessage(),
						       status.getException());
                }
            } catch (IllegalStateException e) {
                e.printStackTrace();
            } catch (TeamRepositoryException e) {
                e.printStackTrace();
                throw e;
            } catch (Exception e) {
                e.printStackTrace();
                throw new TeamRepositoryException(e);
            } finally {
                workingCopyManager.disconnect(handle);
            }

	    // Now check on the results
            IWorkItem item2 = wc_service.findWorkItemById(WorkItemId, IWorkItem.FULL_PROFILE, m);

	    // Was the action sucessful?
	    if (action != null) {
		String newState = item2.getState2().getStringIdentifier();
		String newStateName = workflowInfo.getStateName(item2.getState2());
		if (currentState.equals(newState)) {
		    System.err.println("Error: State transition failed (state remains " +
				       currentStateName + ")");
		} else {
		    System.out.println("Transition: " + currentStateName + " -> " + newStateName);
		}
	    }

	    // Did the resolution get set correctly?
	    // MJW - TODO - This logic is suspect, really should determine the string value
	    //              for the case where the resolution is not set at all, in order to
	    //              correctly report on the case where the resolution is set in the
	    //              first place.  Cosmetic problem at this time.
	    if (iResolution != null) {
		String newResolutionName = workflowInfo.getResolutionName(item2.getResolution2());
		if (currentResolutionName.equals(newResolutionName)) {
			System.out.println("Error: unable to set resolution (remains " +
					   currentResolutionName + ")");
		} else {
		    System.out.println("Resolution set to: " + newResolutionName);
		}
	    }
		    
	    // Print out the final status record, as usual
            Print(item2, workflowInfo, repository, m);

            return item2;

        } else {
            System.out.println("No defect found with ID = " + WorkItemId);
            return null;
        }

    }

    // Query Defect
    public static IWorkItemHandle QueryItem(ITeamRepository repo, IProgressMonitor m, int WorkitemId)
            throws TeamRepositoryException {

        IWorkItemClient wc_service = (IWorkItemClient) repo.getClientLibrary(IWorkItemClient.class);
        IWorkItem workItem = wc_service.findWorkItemById(WorkitemId, IWorkItem.FULL_PROFILE, m);
         if (workItem != null) {
            IWorkflowInfo workflowInfo = wc_service.findWorkflowInfo(workItem, m);
            IWorkItemWorkingCopyManager workingCopyManager = wc_service.getWorkItemWorkingCopyManager();
            IWorkItemHandle handle = wc_service.findWorkItemById(WorkitemId, IWorkItem.FULL_PROFILE, m);
            workingCopyManager.connect(handle, IWorkItem.FULL_PROFILE, m);
            WorkItemWorkingCopy wc = workingCopyManager.getWorkingCopy(handle);
            IWorkItem item = wc.getWorkItem();
            wc_service.getWorkItemWorkingCopyManager().disconnect(item);
            Print(item, workflowInfo, repo, m);
            return item;
        } else {
            System.out.println("No defect found with ID = " + WorkitemId);
            return null;
        }
    }

    // Helper to handle links
    public static IURIReference makeRef(String lURI, String lText) {
	IURIReference ref = null;
	if ((lURI != null) && (lURI.length() > 0)) {
	    try {
		URI l = new URI(lURI);
		if (l != null) {
		    ref = IReferenceFactory.INSTANCE.createReferenceFromURI(l, lText);
		}
	    } catch (URISyntaxException e) {
		System.err.println("Error: " + e.getMessage());
	    }
	}
	return ref;
    }

    // Dump Info on Work Item
    public static IWorkItemHandle DumpInfo(ITeamRepository repository, IProgressMonitor m,
					   String v, int WorkitemId)
            throws TeamRepositoryException {

	System.out.println("RTC_Console Utility, version " + v);
	System.out.println("WorkItem: " + WorkitemId);
        IWorkItemClient wc_service = (IWorkItemClient) repository.getClientLibrary(IWorkItemClient.class);
        IWorkItem workItem = wc_service.findWorkItemById(WorkitemId, IWorkItem.FULL_PROFILE, m);
        if (workItem != null) {
	    System.out.println("WorkitemType: " + workItem.getWorkItemType());

            IWorkflowInfo workflowInfo = wc_service.findWorkflowInfo(workItem, m);
            IWorkItemWorkingCopyManager workingCopyManager = wc_service.getWorkItemWorkingCopyManager();
            IWorkItemHandle hdl = wc_service.findWorkItemById(WorkitemId, IWorkItem.FULL_PROFILE, m);
            workingCopyManager.connect(hdl, IWorkItem.FULL_PROFILE, m);
            WorkItemWorkingCopy wc = workingCopyManager.getWorkingCopy(hdl);
            IWorkItem item = wc.getWorkItem();
	    IProjectArea pa = 
		(IProjectArea) repository.itemManager().fetchCompleteItem(item.getProjectArea(), 0, m);
	    System.out.println("ProjectArea: " + pa.getName());
	    ICategory ca =
		(ICategory) repository.itemManager().fetchCompleteItem(item.getCategory(), 0, m);
	    System.out.println("Category: " + ca.getName());
	    Identifier <IState> st = item.getState2();
	    if (st != null) {
		System.out.println("CurrentState: " + st.getStringIdentifier()
				   + " (" + workflowInfo.getStateName(st) + ")");
	    }
	    Identifier <IResolution> res = item.getResolution2();
	    if (res != null) {
		System.out.println("CurrentResolution: " + res.getStringIdentifier()
				   + " (" + workflowInfo.getResolutionName(res) + ")");
	    }
	    System.out.println("//Defined Types");
	    List<IWorkItemType> types = wc_service.findWorkItemTypes(pa, m);
	    for (IWorkItemType witype : types) {
		System.out.println("Type: " + witype.getIdentifier() +
				   " (" + witype.getDisplayName() + ")");
	    }
	    System.out.println("//Defined Categories");
            List<ICategory> categories = wc_service.findCategories(pa, ICategory.FULL_PROFILE, m);
	    for (ICategory icat : categories) {
		System.out.println("Category: " + icat.getName());
	    }
	    System.out.println("//Defined States");
	    Identifier<IState> stateIds[] = workflowInfo.getAllStateIds();
	    for (Identifier<IState> s : stateIds) {
		System.out.println("State: " + s.getStringIdentifier() +
				   " (" + workflowInfo.getStateName(s) + ")");
	    }		
	    System.out.println("//Defined Actions");
	    Identifier<IWorkflowAction> actionIds[] = workflowInfo.getAllActionIds();
	    for (Identifier<IWorkflowAction> a : actionIds) {
		System.out.println("Action: " + a.getStringIdentifier() +
				   " (" + workflowInfo.getActionName(a) + ")");
	    }		
	    System.out.println("//Defined Resolutions");
            Identifier<IResolution> resIds[] = workflowInfo.getAllResolutionIds();
	    for (Identifier<IResolution> r : resIds) {
		System.out.println("Resolution: " + r.getStringIdentifier() +
				   " (" + workflowInfo.getResolutionName(r) + ")");
	    }		
	    System.out.println("//WorkItem Link Information");
	    IWorkItemReferences refs = wc.getReferences();
	    List<IEndPointDescriptor> endpoints = refs.getTypes();
	    for (IEndPointDescriptor endp : endpoints) {
		System.out.println("EndpointType: " + endp.getLinkType().getLinkTypeId()
				   + " (" + endp.getDisplayName() + ")");
		List<IReference> typedRefs = refs.getReferences(endp);
		for (IReference iref : typedRefs) {
		    if (iref.isURIReference()) {
			URI uri = iref.createURI();
			System.out.println(" URI: " + uri.toString() +
					   " (" + iref.getComment() + ")");
		    }
		}
	    }
	    System.out.println("//End");
            wc_service.getWorkItemWorkingCopyManager().disconnect(item);
            return item;
        } else {
            System.err.println("Error: item could not be retrieved");
            return null;
        }
    }

    // Printing method to return the console result plus a splitting set of
    // characters for later use on plug-in.
    public static void Print(IWorkItem wi, IWorkflowInfo wf, ITeamRepository r, IProgressMonitor m)
            throws TeamRepositoryException {
        System.out.println("Item properties@@@@");
        System.out.println(wi.getId() + ";");
        System.out.println(wi.getHTMLSummary().getPlainText() + ";");
        if (wi.getResolution2() != null) {
            System.out.println(wf.getStateName(wi.getState2()) + ", " +
			       wf.getResolutionName(wi.getResolution2()) + ";");
        } else {
            System.out.println(wf.getStateName(wi.getState2()) + ", null;");
        }
        IProjectArea pa = (IProjectArea) r.itemManager().fetchCompleteItem(wi.getProjectArea(), 0, m);
        System.out.println(pa.getName() + ";");
    }

    // Prints helpful (sort of) usage information
    public static void Usage(String errmsg) {
	if (errmsg != null) {
	    System.err.println(errmsg);
	}
	System.err.println("Usage:");
	System.err.println(" RTC_Console <userid> <passwd> <repoURI> AddItem");
	System.err.println(" RTC_Console <userid> <passwd> <repoURI> QueryItem");
	System.err.println(" RTC_Console <userid> <passwd> <repoURI> UpdateItem");
	System.err.println(" RTC_Console <userid> <passwd> <repoURI> DumpInfo");
	System.exit(1);
    }
}
