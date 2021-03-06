@{
    Name = 'The PowerShell View System'
    PSTypeName = 'http://shouldbeonschema.org/Topic'
    Content = @'
One of the most important things to understand about PowerShell Pipeworks is how the view system built into PowerShell is leveraged.




In PowerShell, you're constantly running into different types of data, so how you're exposed to this information means a lot.
Because of this, there is a very flexible types and formatting system in PowerShell.  
You can define a view for any type of object, and, by default, PowerShell will show you every property that object has.  
Pipeworks works the same way:  You can let it display a table of properties on an object, or you can declare a view.


Also, just like PowerShell ships with views for types you're going to see a lot (like WMI classes or performance counters), Pipeworks ships with a lot of views for the types of objects you'll find on the web.  

It can do this on the backs of [Schema.org](http://schema.org/) and the sister site we run: [ShouldBeOnSchema.org](http://shouldbeonschema.org).  These sites keep common lists of property bags you can use, and the most common of these property bags are views included with Pipeworks. 





You can also declare your own views, using a module called [EZOut](http://ezout.start-automating.com).
'@    
    Related = @'
[Schema.org](http://schema.org) [ShouldBeOnSchema.org](http://ShouldBeOnSchema.org) [EZOut](http://ezout.start-automating.com)
'@

}