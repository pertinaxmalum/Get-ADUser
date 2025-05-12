function Get-ADUser {
    param (
        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateSet("samaccountname", "title", "displayName","department","directorate","division","objectSID","mail","linemanager","grade","servicePrincipalName","samaccounttype","group", IgnoreCase = $true)]
        [string]$SearchParameter = "samaccountname",

        [Parameter(Mandatory = $false, Position = 0)]
        [string]$SearchValue,

        [Parameter(Mandatory = $false, Position = 2)]
        [string]$objectClass = "user",

        [Parameter(Mandatory = $false, Position = 3)]
        [string]$filter,

        [Parameter(Mandatory = $false, Position = 4)]
        [switch]$RecurOnLineManager,

        [Parameter(Mandatory = $false, Position = 5)]
        [array]$PropertiesToLoad = @("samaccountname","displayName", "mail", "title", "department", "extensionAttribute3", "extensionAttribute7", "extensionAttribute11","extensionattribute14","objectsid")


    )

    function Get-ADData($internalObjectClass, $internalSearchParameter, $internalSearchValue, $internalDomain) {

        $searcher = New-Object System.DirectoryServices.DirectorySearcher
        $searcher.SearchRoot = $internalDomain
            
        if ($internalSearchParameter -eq 'group') {
            $searcher.Filter = "(&(objectClass=group)(sAMAccountName=$internalSearchValue))"
        }   elseif (!$filter) {  
            $searcher.Filter = "(&(objectClass=$internalObjectClass)($internalSearchParameter=$internalSearchValue))"
        } else {
            $searcher.Filter = $filter
        }

        # to populate the group based search with the member data rather than just the group data
        if ($internalSearchParameter -ne 'group') {

            foreach ($property in $propertiesToLoad) {
                $searcher.PropertiesToLoad.Add($property) | Out-Null
            }

            $results = $searcher.FindAll()
        } else {
            $groupMembersCnOnly = $searcher.FindAll().properties.member

            $results = @()

            foreach ($member in $groupMembersCnOnly) {
                $internalUserSearcher = New-Object System.DirectoryServices.DirectorySearcher
                $internalUserSearcher.Filter = "(&(objectClass=user)(distinguishedName=$member))"

               foreach ($property in $propertiesToLoad) {
                    $internalUserSearcher.PropertiesToLoad.Add($property) | Out-Null
                }
                
                $results += $internalUserSearcher.FindAll()
            }

            
        }


        $internalUserProperties = @()

        foreach ($result in $results) {
            $internalUserProperties += [PSCustomObject]@{
                SamAccountName   = $result.Properties["samaccountname"] -join ", "
                DisplayName      = $result.Properties["displayname"] -join ", "
                Email            = $result.Properties["mail"] -join ", "
                Title            = $result.Properties["title"] -join ", "
                Department       = $result.Properties["department"] -join ", "
                Directorate      = $result.Properties["extensionattribute7"] -join ", "
                Division         = $result.Properties["extensionattribute3"] -join ", "
                Grade            = $result.Properties["extensionattribute11"] -join ", "
                LineManager      = $result.Properties["extensionattribute14"] -join "," 
                SID              = $(New-Object System.Security.Principal.SecurityIdentifier($result.Properties["objectSID"][0], 0)) -join ", "
            }
        }

        return $internalUserProperties
    }

    $domain = New-Object System.DirectoryServices.DirectoryEntry

    # If we later want to have fields that have extension names we can use a switch here where the default is the supplied value,
    # otherwise it is corrected at this point

    switch ($SearchParameter) {
        directorate {$passedInSearchParameter = 'extensionattribute7'}
        division {$passedInSearchParameter = 'extensionattribute3'}
        linemanager {$passedInSearchParameter = 'extensionattribute14'}
        grade {$passedInSearchParameter = 'extensionattribute11'}
        default {$passedInSearchParameter = $SearchParameter}
    }

    $userProperties = @()

    if ($RecurOnLineManager) {
        $result = @()
        
        $thisResult = Get-ADData -internalObjectClass $objectClass -internalSearchParameter $passedInSearchParameter -internalSearchValue $SearchValue -internalDomain $domain

        $result += $thisResult

        while ($thisResult.linemanager) {
            $thisResult = Get-ADData -internalObjectClass $objectClass -internalSearchParameter mail -internalSearchValue $thisResult.linemanager -internalDomain $domain
            $result += $thisResult
        } 

        $userProperties = $result
    }   else {
        $userProperties += Get-ADData -internalObjectClass $objectClass -internalSearchParameter $passedInSearchParameter -internalSearchValue $SearchValue -internalDomain $domain
    }

    return $userProperties
}
