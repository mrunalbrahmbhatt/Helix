namespace NamespacePrefix.ModuleType.ModuleName.Controllers
{
  using System;
  using System.Web.Mvc;
  using Sitecore.Data;
  using Repositories;

  public class ModuleNameController : Sitecore.Mvc.Controllers.SitecoreController
  {
    private readonly IModuleNameRepository ModuleNameRepository;

    public ModuleNameController() : this(new ModuleNameRepository())
    {
    }

    public ModuleNameController(IModuleNameRepository ModuleNameRepository)
    {
      this.ModuleNameRepository = ModuleNameRepository;
    }

    public ActionResult ModuleName()
    {
        /* 
          TODO: Use the repository to retrieve model data 
          which can be passed into the view.
        */

       //var model = ModuleNameRepository. ;
       //
       //return this.View(model);
       
       throw new NotImplementedException();
    }
  }
}